// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "../../../src/contracts/Registry.sol";
import {MockToken} from "../../mocks/MockToken.sol";
import {MockEscrow} from "../../mocks/MockEscrow.sol";
import {Badges} from "../../../src/contracts/Badges.sol";
import {MockDisputeResolver} from "../../mocks/MockDisputeResolver.sol";
import {IRegistry} from "../../../src/interfaces/IRegistry.sol";
import {IDisputeResolver} from "../../../src/interfaces/IDisputeResolver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RegistryAccessControlTest is Test {
    // Contract instances
    Registry public registry;
    MockToken public token;
    MockEscrow public escrow;
    Badges public badges;
    MockDisputeResolver public disputeResolver;

    // Test users
    address public owner;
    address public tasker;
    address public beneficiary;
    address public unauthorized;

    // Service details
    uint40 public serviceId;

    function setUp() public {
        // Deploy mock dependencies
        token = new MockToken("TestToken", "TTK");
        escrow = new MockEscrow();
        badges = new Badges(address(this));

        // Deploy registry as owner
        owner = makeAddr("Owner");
        vm.prank(owner);
        registry = new Registry(address(token), address(escrow));

        // Setup test users
        tasker = makeAddr("Tasker");
        beneficiary = makeAddr("Beneficiary");
        unauthorized = makeAddr("Unauthorized");

        // Mint tokens and set initial balances
        token.mint(tasker, 1000 ether);

        vm.startPrank(tasker);
        registry.addService("Test Service");
        serviceId = 0; // First service
        vm.stopPrank();
    }

    // Tests for setDisputeResolver
    function test_setDisputeResolver_success() public {
        // Arrange
        disputeResolver = new MockDisputeResolver();

        // Act & Assert
        vm.prank(owner);
        registry.setDisputeResolver(disputeResolver);

        // Verify state change
        assertEq(address(registry.disputeResolver()), address(disputeResolver));
    }

    function test_setDisputeResolver_revertWhen_calledByNonOwner() public {
        // Arrange
        disputeResolver = new MockDisputeResolver();

        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        registry.setDisputeResolver(disputeResolver);
    }

    function test_setDisputeResolver_revertWhen_zeroAddress() public {
        // Act & Assert
        vm.prank(owner);
        vm.expectRevert(IRegistry.InvalidDisputeResolver.selector);
        registry.setDisputeResolver(IDisputeResolver(address(0)));
    }

    // Tests for updateService
    function test_updateService_revertWhen_calledByNonTasker() public {
        // Arrange
        string memory newDescription = "Updated Service Description";

        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.updateService(serviceId, newDescription);
    }

    // Tests for createDeal

    function test_createDeal_revertWhen_calledByNonTasker() public {
        // Arrange
        uint256 price = 50 ether;
        string memory agreementURI = "https://example.com/agreement";

        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.createDeal(serviceId, price, beneficiary, 1 days, agreementURI);
    }

    function test_createDeal_revertWhen_invalidBeneficiary() public {
        // Act & Assert
        vm.prank(tasker);
        vm.expectRevert(IRegistry.InvalidBeneficiary.selector);
        registry.createDeal(serviceId, 50 ether, address(0), 1 days, "https://example.com/agreement");
    }

    // Tests for rate

    function test_rate_revertWhen_calledByUnauthorized() public {
        // Arrange
        // First create a deal
        uint256 price = 50 ether;
        string memory agreementURI = "https://example.com/agreement";

        // Mint tokens to beneficiary
        vm.startPrank(beneficiary);
        token.mint(beneficiary, 100 ether);
        token.approve(address(registry), 100 ether);
        vm.stopPrank();

        // Create deal
        vm.prank(tasker);
        registry.createDeal(serviceId, price, beneficiary, 1 days, agreementURI);
        uint40 dealId = 0; // First deal

        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.rate(dealId, 5, "Not authorized!");
    }

    // Tests for dispute
    function test_dispute_revertWhen_noDisputeResolver() public {
        // Act & Assert
        vm.expectRevert(IRegistry.DisputeResolverNotSet.selector);
        vm.prank(beneficiary);
        registry.dispute(serviceId);
    }

    function test_dispute_successWhenDisputeResolverSet() public {
        // Arrange
        disputeResolver = new MockDisputeResolver();

        // Set dispute resolver
        vm.prank(owner);
        registry.setDisputeResolver(disputeResolver);

        // Act & Assert
        vm.prank(beneficiary);
        registry.dispute(serviceId);
    }

    // Tests for Ownable2Step ownership transfer
    function test_transferOwnership_twoStepProcess() public {
        // Arrange
        address newOwner = makeAddr("NewOwner");

        // Act - Step 1: Current owner initiates transfer
        vm.prank(owner);
        registry.transferOwnership(newOwner);

        // Assert - Ownership not yet transferred
        assertEq(registry.owner(), owner, "Owner should not change until accepted");
        assertEq(registry.pendingOwner(), newOwner, "Pending owner should be set");

        // Act - Step 2: New owner accepts ownership
        vm.prank(newOwner);
        registry.acceptOwnership();

        // Assert - Ownership transferred
        assertEq(registry.owner(), newOwner, "Owner should be new owner");
        assertEq(registry.pendingOwner(), address(0), "Pending owner should be cleared");
    }

    function test_transferOwnership_revertWhen_calledByNonOwner() public {
        // Arrange
        address newOwner = makeAddr("NewOwner");

        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        registry.transferOwnership(newOwner);
    }

    function test_acceptOwnership_revertWhen_calledByNonPendingOwner() public {
        // Arrange
        address newOwner = makeAddr("NewOwner");

        vm.prank(owner);
        registry.transferOwnership(newOwner);

        // Act & Assert - Unauthorized tries to accept
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        registry.acceptOwnership();
    }

    function test_transferOwnership_newOwnerCanUseOnlyOwnerFunctions() public {
        // Arrange
        address newOwner = makeAddr("NewOwner");
        disputeResolver = new MockDisputeResolver();

        // Transfer ownership
        vm.prank(owner);
        registry.transferOwnership(newOwner);

        vm.prank(newOwner);
        registry.acceptOwnership();

        // Act & Assert - New owner can call onlyOwner functions
        vm.prank(newOwner);
        registry.setDisputeResolver(disputeResolver);

        assertEq(
            address(registry.disputeResolver()),
            address(disputeResolver),
            "New owner should be able to set dispute resolver"
        );
    }

    function test_transferOwnership_oldOwnerCannotUseOnlyOwnerFunctions() public {
        // Arrange
        address newOwner = makeAddr("NewOwner");
        disputeResolver = new MockDisputeResolver();

        // Transfer ownership
        vm.prank(owner);
        registry.transferOwnership(newOwner);

        vm.prank(newOwner);
        registry.acceptOwnership();

        // Act & Assert - Old owner cannot call onlyOwner functions
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        registry.setDisputeResolver(disputeResolver);
    }

    function test_renounceOwnership_successful() public {
        // Act
        vm.prank(owner);
        registry.renounceOwnership();

        // Assert - Ownership renounced (owner set to address(0))
        assertEq(registry.owner(), address(0), "Owner should be zero address");
    }

    function test_renounceOwnership_revertWhen_calledByNonOwner() public {
        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        registry.renounceOwnership();
    }
}
