// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "../../../src/contracts/Registry.sol";
import {Badges} from "../../../src/contracts/Badges.sol";
import {IRegistry} from "../../../src/interfaces/IRegistry.sol";
import {MockEscrow} from "../../mocks/MockEscrow.sol";
import {MockToken} from "../../mocks/MockToken.sol";

contract RegistryCreateDealTest is Test {
    Registry public registry;
    MockToken public token;
    Badges public badges;
    MockEscrow public escrow;

    // Test users
    address public owner;
    address public tasker;
    address public beneficiary;
    address public anotherTasker;
    address public unauthorized;

    // Test data
    uint256 constant INITIAL_BALANCE = 1000e18;
    uint256 constant STAKE_AMOUNT = 500e18;
    uint40 public serviceId;
    uint40 public anotherServiceId;

    // Events to test
    event DealCreated(uint40 _dealId);

    function setUp() public {
        // Setup test users
        owner = makeAddr("owner");
        tasker = makeAddr("tasker");
        beneficiary = makeAddr("beneficiary");
        anotherTasker = makeAddr("anotherTasker");
        unauthorized = makeAddr("unauthorized");

        // Deploy mock contracts
        token = new MockToken("TestToken", "TTK");
        badges = new Badges(address(this));
        escrow = new MockEscrow();

        // Deploy registry
        vm.prank(owner);
        registry = new Registry(address(token), address(escrow));

        // Setup initial state
        token.mint(tasker, INITIAL_BALANCE);
        token.mint(anotherTasker, INITIAL_BALANCE);
        token.mint(beneficiary, INITIAL_BALANCE);

        // Create services for testing
        vm.startPrank(tasker);
        registry.addService("Main Test Service");
        serviceId = 0; // First service
        vm.stopPrank();

        vm.startPrank(anotherTasker);
        registry.addService("Another Test Service");
        anotherServiceId = 1; // Second service
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             SUCCESS CASES
    //////////////////////////////////////////////////////////////*/

    function test_createDeal_success() public {
        // Arrange
        uint256 dealPrice = 100e18;
        string memory agreementURI = "ipfs://QmTestAgreement";

        // Act
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, agreementURI);

        // Assert - verify deal was created
        (uint40 dealId, uint40 dealServiceId, address dealBeneficiary, uint256 agreementId, uint256 price) =
            registry.deals(0);

        assertEq(dealId, 0, "Deal ID should be 0");
        assertEq(dealServiceId, serviceId, "Deal service ID should match");
        assertEq(dealBeneficiary, beneficiary, "Deal beneficiary should match");
        assertEq(price, dealPrice, "Deal price should match");
        assertTrue(agreementId > 0, "Agreement ID should be set");
    }

    function test_createDeal_correctEscrowBuyerAndSeller() public {
        // Arrange
        uint256 dealPrice = 100e18;
        string memory agreementURI = "ipfs://QmTestAgreement";

        // Act
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, agreementURI);

        // Assert - verify escrow transaction has correct buyer and seller
        (,, address dealBeneficiary, uint256 agreementId,) = registry.deals(0);

        // Get buyer and seller from escrow transaction
        (address payable buyer, address payable seller,,,,,,,,,,) = escrow.transactions(agreementId);
        // In escrow context:
        // - buyer = the beneficiary (customer who will receive the service and pays for it)
        // - seller = the tasker (service provider who receives payment)
        assertEq(buyer, beneficiary, "Escrow buyer should be the beneficiary");
        assertEq(seller, tasker, "Escrow seller should be the tasker");

        // Get deadline separately to avoid stack too deep
        (,,,,, uint256 deadline,,,,,,) = escrow.transactions(agreementId);
        assertEq(deadline, block.timestamp + 1 days, "Escrow deadline should match");
    }

    function test_createDeal_multipleDealsSameService() public {
        // Arrange
        uint256 dealPrice1 = 100e18;
        uint256 dealPrice2 = 200e18;
        address beneficiary2 = makeAddr("beneficiary2");

        // Act
        vm.startPrank(tasker);
        registry.createDeal(serviceId, dealPrice1, beneficiary, 1 days, "agreement1");
        registry.createDeal(serviceId, dealPrice2, beneficiary2, 1 days, "agreement2");
        vm.stopPrank();

        // Assert - verify both deals were created
        (uint40 dealId1,,,, uint256 price1) = registry.deals(0);
        (uint40 dealId2,,,, uint256 price2) = registry.deals(1);

        assertEq(dealId1, 0, "First deal ID should be 0");
        assertEq(dealId2, 1, "Second deal ID should be 1");
        assertEq(price1, dealPrice1, "First deal price should match");
        assertEq(price2, dealPrice2, "Second deal price should match");
    }

    function test_createDeal_differentTaskers() public {
        // Arrange
        uint256 dealPrice = 150e18;

        // Act - Both taskers create deals for their own services
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "tasker1_deal");

        vm.prank(anotherTasker);
        registry.createDeal(anotherServiceId, dealPrice, beneficiary, 1 days, "tasker2_deal");

        // Assert
        (, uint40 deal1ServiceId,,,) = registry.deals(0);
        (, uint40 deal2ServiceId,,,) = registry.deals(1);

        assertEq(deal1ServiceId, serviceId, "First deal should be for tasker's service");
        assertEq(deal2ServiceId, anotherServiceId, "Second deal should be for another tasker's service");
    }

    function test_createDeal_escrowDataForDifferentTaskers() public {
        // Arrange
        uint256 dealPrice = 150e18;

        // Act - Both taskers create deals for their own services
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "tasker1_deal");

        vm.prank(anotherTasker);
        registry.createDeal(anotherServiceId, dealPrice, beneficiary, 1 days, "tasker2_deal");

        // Assert - Verify escrow has correct buyer/seller for each deal
        (,,, uint256 agreementId1,) = registry.deals(0);
        (,,, uint256 agreementId2,) = registry.deals(1);

        // First deal: buyer=beneficiary, seller=tasker
        // New format: (buyer, seller, amount, settlementBuyer, settlementSeller, deadline, ...)
        (address payable buyer1, address payable seller1,,,,,,,,,,) = escrow.transactions(agreementId1);
        assertEq(buyer1, beneficiary, "First deal: buyer should be beneficiary");
        assertEq(seller1, tasker, "First deal: seller should be tasker");

        // Second deal: buyer=beneficiary, seller=anotherTasker
        (address payable buyer2, address payable seller2,,,,,,,,,,) = escrow.transactions(agreementId2);
        assertEq(buyer2, beneficiary, "Second deal: buyer should be beneficiary");
        assertEq(seller2, anotherTasker, "Second deal: seller should be anotherTasker");
    }

    function test_createDeal_withDifferentBeneficiaries() public {
        // Arrange
        address beneficiary2 = makeAddr("beneficiary2");
        address beneficiary3 = makeAddr("beneficiary3");
        uint256 dealPrice = 75e18;

        // Act
        vm.startPrank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "deal1");
        registry.createDeal(serviceId, dealPrice, beneficiary2, 1 days, "deal2");
        registry.createDeal(serviceId, dealPrice, beneficiary3, 1 days, "deal3");
        vm.stopPrank();

        // Assert
        (,, address deal1Beneficiary,,) = registry.deals(0);
        (,, address deal2Beneficiary,,) = registry.deals(1);
        (,, address deal3Beneficiary,,) = registry.deals(2);

        assertEq(deal1Beneficiary, beneficiary, "First deal beneficiary should match");
        assertEq(deal2Beneficiary, beneficiary2, "Second deal beneficiary should match");
        assertEq(deal3Beneficiary, beneficiary3, "Third deal beneficiary should match");
    }

    function test_createDeal_variousPrices() public {
        // Arrange
        uint256[] memory prices = new uint256[](4);
        prices[0] = 1e18; // 1 token
        prices[1] = 50e18; // 50 tokens
        prices[2] = 1000e18; // 1000 tokens
        prices[3] = 0; // Free service

        // Act & Assert
        vm.startPrank(tasker);
        for (uint256 i = 0; i < prices.length; i++) {
            registry.createDeal(serviceId, prices[i], beneficiary, 1 days, "test_deal");
            (,,,, uint256 dealPrice) = registry.deals(i);
            assertEq(dealPrice, prices[i], "Deal price should match expected price");
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_createDeal_revertWhen_calledByNonTasker() public {
        // Arrange
        uint256 dealPrice = 100e18;

        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "unauthorized_deal");
    }

    function test_createDeal_revertWhen_differentTaskerTriesToCreateDeal() public {
        // Arrange
        uint256 dealPrice = 100e18;

        // Act & Assert - anotherTasker tries to create deal for tasker's service
        vm.prank(anotherTasker);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "cross_tasker_deal");
    }

    function test_createDeal_revertWhen_invalidBeneficiary() public {
        // Arrange
        uint256 dealPrice = 100e18;

        // Act & Assert
        vm.prank(tasker);
        vm.expectRevert(IRegistry.InvalidBeneficiary.selector);
        registry.createDeal(serviceId, dealPrice, address(0), 1 days, "invalid_beneficiary");
    }

    function test_createDeal_revertWhen_nonExistentService() public {
        // Arrange
        uint40 nonExistentServiceId = 999;
        uint256 dealPrice = 100e18;

        // Act & Assert
        vm.prank(tasker);
        vm.expectRevert(IRegistry.InvalidServiceId.selector);
        registry.createDeal(nonExistentServiceId, dealPrice, beneficiary, 1 days, "nonexistent_service");
    }

    /*//////////////////////////////////////////////////////////////
                              EVENT TESTING
    //////////////////////////////////////////////////////////////*/

    function test_createDeal_emitsDealCreatedEvent() public {
        // Arrange
        uint256 dealPrice = 100e18;

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit DealCreated(0);

        // Act
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "event_test_deal");
    }

    function test_createDeal_emitsMultipleEvents() public {
        // Arrange
        uint256 dealPrice = 100e18;

        vm.startPrank(tasker);

        // First event
        vm.expectEmit(true, false, false, true);
        emit DealCreated(0);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "deal1");

        // Second event
        vm.expectEmit(true, false, false, true);
        emit DealCreated(1);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "deal2");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_createDeal_sameBeneficiaryMultipleDeals() public {
        // Arrange
        uint256 dealPrice = 100e18;

        // Act - Create multiple deals with same beneficiary
        vm.startPrank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "deal1");
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "deal2");
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "deal3");
        vm.stopPrank();

        // Assert - All deals should be created successfully
        for (uint256 i = 0; i < 3; i++) {
            (,, address dealBeneficiary,,) = registry.deals(i);
            assertEq(dealBeneficiary, beneficiary, "All deals should have same beneficiary");
        }
    }

    function test_createDeal_taskerAsBeneficiary() public {
        // Arrange
        uint256 dealPrice = 100e18;

        // Act - Tasker creates deal where they are also the beneficiary
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, tasker, 1 days, "self_benefit_deal");

        // Assert
        (,, address dealBeneficiary,,) = registry.deals(0);
        assertEq(dealBeneficiary, tasker, "Tasker should be able to be their own beneficiary");
    }

    function test_createDeal_emptyAgreementURI() public {
        // Arrange
        uint256 dealPrice = 100e18;
        string memory emptyURI = "";

        // Act & Assert - Should succeed with empty URI
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, emptyURI);

        // Verify deal was created
        (uint40 dealId,,,, uint256 price) = registry.deals(0);
        assertEq(dealId, 0, "Deal should be created with empty URI");
        assertEq(price, dealPrice, "Deal price should still be set correctly");
    }

    function test_createDeal_longAgreementURI() public {
        // Arrange
        uint256 dealPrice = 100e18;
        string memory longURI = string(
            abi.encodePacked(
                "ipfs://QmVeryLongAgreementURIThatContainsLotsOfTextAndInformation",
                "WithAdditionalMetadataAndDescriptionsThatMightBeUsedInARealWorld",
                "ScenarioWhereTheAgreementContainsComprehensiveTermsAndConditions"
            )
        );

        // Act & Assert - Should succeed with long URI
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, longURI);

        // Verify deal was created
        (uint40 dealId,,,, uint256 price) = registry.deals(0);
        assertEq(dealId, 0, "Deal should be created with long URI");
        assertEq(price, dealPrice, "Deal price should be set correctly");
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_createDeal_doesNotAffectOtherServices() public {
        // Arrange
        uint256 dealPrice = 100e18;

        // Act - Create deal for one service
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "isolated_deal");

        // Assert - Other service should be unaffected
        (uint40 otherServiceId, address otherTasker,) = registry.services(anotherServiceId);
        assertEq(otherServiceId, anotherServiceId, "Other service ID should be unchanged");
        assertEq(otherTasker, anotherTasker, "Other service tasker should be unchanged");
    }

    function test_createDeal_doesNotAffectStakes() public {
        // Arrange
        uint256 dealPrice = 100e18;
        (, uint256 initialStake) = registry.users(tasker);

        // Act
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, "stake_test_deal");

        // Assert - Stake should be unchanged
        (, uint256 finalStake) = registry.users(tasker);
        assertEq(finalStake, initialStake, "Tasker's stake should be unchanged after creating deal");
    }

    /*//////////////////////////////////////////////////////////////
                            GAS TESTING
    //////////////////////////////////////////////////////////////*/

    function test_createDeal_gasConsumption() public {
        // Arrange
        uint256 dealPrice = 100e18;
        string memory agreementURI = "ipfs://QmTestGasConsumption";

        // Act & Assert - Log gas usage for reference
        vm.prank(tasker);
        registry.createDeal(serviceId, dealPrice, beneficiary, 1 days, agreementURI);
    }
}
