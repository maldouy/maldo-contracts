// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "../../../src/contracts/Registry.sol";
import {Badges} from "../../../src/contracts/Badges.sol";
import {IRegistry} from "../../../src/interfaces/IRegistry.sol";
import {MockEscrow} from "../../mocks/MockEscrow.sol";
import {MockToken} from "../../mocks/MockToken.sol";

contract RegistryRateTest is Test {
    Registry public registry;
    MockToken public token;
    Badges public badges;
    MockEscrow public escrow;

    // Test users
    address public owner;
    address public tasker;
    address public beneficiary;
    address public anotherTasker;
    address public anotherBeneficiary;
    address public unauthorized;

    // Test data
    uint256 constant INITIAL_BALANCE = 1000e18;
    uint256 constant STAKE_AMOUNT = 500e18;
    uint256 constant DEAL_PRICE = 100e18;

    uint40 public serviceId;
    uint40 public dealId;

    // Events to test
    event Rated(uint40 _dealId, address indexed _reviewer, uint8 _rating);

    function setUp() public {
        // Setup test users
        owner = makeAddr("owner");
        tasker = makeAddr("tasker");
        beneficiary = makeAddr("beneficiary");
        anotherTasker = makeAddr("anotherTasker");
        anotherBeneficiary = makeAddr("anotherBeneficiary");
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
        token.mint(beneficiary, INITIAL_BALANCE);
        token.mint(anotherTasker, INITIAL_BALANCE);

        // Create service and deal for testing
        vm.startPrank(tasker);
        registry.addService("Test Service for Rating");
        serviceId = 0;
        registry.createDeal(serviceId, DEAL_PRICE, beneficiary, 1 days, "rating-test-deal");
        dealId = 0;
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          SUCCESS CASES - BENEFICIARY
    //////////////////////////////////////////////////////////////*/

    function test_rate_successByBeneficiary() public {
        // Arrange
        uint8 rating = 5;
        string memory review = "Excellent service, highly recommended!";

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, review);

        // Assert - Check that rating was stored in customerReview
        (uint8 taskerRating, string memory taskerReview, uint8 customerRating, string memory customerReview) =
            registry.dealReviews(dealId);
        assertEq(customerRating, rating, "Customer rating should match");
        assertEq(customerReview, review, "Customer review should match");
        assertEq(taskerRating, 0, "Tasker rating should be unset");
        assertEq(bytes(taskerReview).length, 0, "Tasker review should be empty");
    }

    function test_rate_revertWhen_beneficiaryRatesTwice() public {
        // Arrange
        uint8 rating1 = 4;
        uint8 rating2 = 5;
        string memory review1 = "Good service";
        string memory review2 = "Updated: Great service!";

        // Act - First rating succeeds
        vm.prank(beneficiary);
        registry.rate(dealId, rating1, review1);

        // Second rating should fail
        vm.prank(beneficiary);
        vm.expectRevert(IRegistry.AlreadyReviewed.selector);
        registry.rate(dealId, rating2, review2);
    }

    /*//////////////////////////////////////////////////////////////
                           SUCCESS CASES - TASKER
    //////////////////////////////////////////////////////////////*/

    function test_rate_successByTasker() public {
        // Arrange
        uint8 rating = 5;
        string memory review = "Professional client, smooth transaction";

        // Act
        vm.prank(tasker);
        registry.rate(dealId, rating, review);

        // Assert - Check that rating was stored in taskerReview
        (uint8 taskerRating, string memory taskerReview, uint8 customerRating, string memory customerReview) =
            registry.dealReviews(dealId);
        assertEq(taskerRating, rating, "Tasker rating should match");
        assertEq(taskerReview, review, "Tasker review should match");
        assertEq(customerRating, 0, "Customer rating should be unset");
        assertEq(bytes(customerReview).length, 0, "Customer review should be empty");
    }

    function test_rate_revertWhen_taskerRatesTwice() public {
        // Arrange
        uint8 rating1 = 3;
        uint8 rating2 = 4;
        string memory review1 = "Client was okay";
        string memory review2 = "Client improved communication";

        // Act - First rating succeeds
        vm.prank(tasker);
        registry.rate(dealId, rating1, review1);

        // Second rating should fail
        vm.prank(tasker);
        vm.expectRevert(IRegistry.AlreadyReviewed.selector);
        registry.rate(dealId, rating2, review2);
    }

    /*//////////////////////////////////////////////////////////////
                      SUCCESS CASES - BOTH PARTIES
    //////////////////////////////////////////////////////////////*/

    function test_rate_bothPartiesCanRate() public {
        // Arrange
        uint8 beneficiaryRating = 5;
        uint8 taskerRatingValue = 4;
        string memory beneficiaryReview = "Great service provider";
        string memory taskerReviewText = "Reliable client";

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, beneficiaryRating, beneficiaryReview);

        vm.prank(tasker);
        registry.rate(dealId, taskerRatingValue, taskerReviewText);

        // Assert - Both reviews should be stored
        (uint8 taskerRating, string memory taskerReview, uint8 customerRating, string memory customerReview) =
            registry.dealReviews(dealId);

        assertEq(customerRating, beneficiaryRating, "Customer rating should match");
        assertEq(customerReview, beneficiaryReview, "Customer review should match");
        assertEq(taskerRating, taskerRatingValue, "Tasker rating should match");
        assertEq(taskerReview, taskerReviewText, "Tasker review should match");
    }

    /*//////////////////////////////////////////////////////////////
                              ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_rate_revertWhen_calledByUnauthorized() public {
        // Arrange
        uint8 rating = 5;
        string memory review = "Unauthorized review";

        // Act & Assert
        vm.prank(unauthorized);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.rate(dealId, rating, review);
    }

    function test_rate_revertWhen_calledByAnotherTasker() public {
        // Arrange
        uint8 rating = 5;
        string memory review = "Another tasker's review";

        // Setup another tasker with service
        vm.startPrank(anotherTasker);
        registry.addService("Another Service");
        vm.stopPrank();

        // Act & Assert
        vm.prank(anotherTasker);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.rate(dealId, rating, review);
    }

    function test_rate_revertWhen_calledByAnotherBeneficiary() public {
        // Arrange
        uint8 rating = 5;
        string memory review = "Another beneficiary's review";

        // Act & Assert
        vm.prank(anotherBeneficiary);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.rate(dealId, rating, review);
    }

    function test_rate_revertWhen_nonExistentDeal() public {
        // Arrange
        uint40 nonExistentDealId = 999;
        uint8 rating = 5;
        string memory review = "Review for non-existent deal";

        // Act & Assert
        vm.prank(beneficiary);
        vm.expectRevert(IRegistry.InvalidDealId.selector);
        registry.rate(nonExistentDealId, rating, review);
    }

    /*//////////////////////////////////////////////////////////////
                              EVENT TESTING
    //////////////////////////////////////////////////////////////*/

    function test_rate_emitsRatedEvent() public {
        // Arrange
        uint8 rating = 5;
        string memory review = "Event test review";

        // Expect event with reviewer address
        vm.expectEmit(true, true, false, true);
        emit Rated(dealId, beneficiary, rating);

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, review);
    }

    function test_rate_emitsMultipleEvents() public {
        // Arrange
        uint8 rating1 = 4;
        uint8 rating2 = 5;

        // First event from beneficiary
        vm.expectEmit(true, true, false, true);
        emit Rated(dealId, beneficiary, rating1);
        vm.prank(beneficiary);
        registry.rate(dealId, rating1, "First rating");

        // Second event from tasker
        vm.expectEmit(true, true, false, true);
        emit Rated(dealId, tasker, rating2);
        vm.prank(tasker);
        registry.rate(dealId, rating2, "Second rating");
    }

    /*//////////////////////////////////////////////////////////////
                              EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_rate_allRatingValues() public {
        // Test all valid rating values (1-5) using different deals
        // Note: Rating 0 is invalid as it's used as sentinel for "not rated"
        for (uint8 rating = 1; rating <= 5; rating++) {
            // Create a new deal for each rating test
            vm.prank(tasker);
            registry.createDeal(serviceId, DEAL_PRICE, beneficiary, 1 days, "rating-value-test");
            uint40 testDealId = uint40(rating); // dealId starts at 0, ratings start at 1

            // Rate the deal
            vm.prank(beneficiary);
            string memory review = string(abi.encodePacked("Rating: ", uint256(rating)));
            registry.rate(testDealId, rating, review);

            // Verify the rating was stored correctly
            (, , uint8 customerRating, string memory customerReview) = registry.dealReviews(testDealId);
            assertEq(customerRating, rating, "Rating should match expected value");
            assertEq(customerReview, review, "Review should match");
        }
    }

    function test_rate_revertWhen_ratingTooHigh() public {
        // Test that ratings above MAX_RATING (5) are rejected
        vm.prank(beneficiary);
        vm.expectRevert(IRegistry.InvalidRating.selector);
        registry.rate(dealId, 6, "Rating too high");

        // Test with max uint8 value
        vm.prank(beneficiary);
        vm.expectRevert(IRegistry.InvalidRating.selector);
        registry.rate(dealId, 255, "Max uint8 rating should be rejected");
    }

    function test_rate_revertWhen_ratingIsZero() public {
        // Rating 0 is invalid as it's used as sentinel for "not rated"
        vm.prank(beneficiary);
        vm.expectRevert(IRegistry.InvalidRating.selector);
        registry.rate(dealId, 0, "Zero rating should be rejected");
    }

    function test_rate_emptyReview() public {
        // Arrange
        uint8 rating = 5;
        string memory emptyReview = "";

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, emptyReview);

        // Assert
        (, , uint8 customerRating, string memory customerReview) = registry.dealReviews(dealId);
        assertEq(customerReview, emptyReview, "Should accept empty review");
        assertEq(customerRating, rating, "Rating should still be set");
    }

    function test_rate_longReview() public {
        // Arrange
        uint8 rating = 4;
        string memory longReview = string(
            abi.encodePacked(
                "This is a very long and detailed review that contains extensive feedback ",
                "about the service provided. The review includes multiple paragraphs of text ",
                "with specific details about the quality, timeliness, communication, and overall ",
                "satisfaction with the service. This tests the contract's ability to handle ",
                "large amounts of text in reviews without any issues or limitations."
            )
        );

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, longReview);

        // Assert
        (, , , string memory customerReview) = registry.dealReviews(dealId);
        assertEq(customerReview, longReview, "Should accept long review");
    }

    function test_rate_specialCharactersInReview() public {
        // Arrange
        uint8 rating = 5;
        string memory specialReview = "Great service! 5/5 stars - 100% satisfied!";

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, specialReview);

        // Assert
        (, , , string memory customerReview) = registry.dealReviews(dealId);
        assertEq(customerReview, specialReview, "Should accept special characters");
    }

    /*//////////////////////////////////////////////////////////////
                         MULTIPLE DEALS TESTING
    //////////////////////////////////////////////////////////////*/

    function test_rate_multipleDealsSameService() public {
        // Arrange - Create second deal for same service
        vm.prank(tasker);
        registry.createDeal(serviceId, DEAL_PRICE, anotherBeneficiary, 1 days, "second-deal");
        uint40 secondDealId = 1;

        // Act - Rate both deals
        vm.prank(beneficiary);
        registry.rate(dealId, 5, "First deal rating");

        vm.prank(anotherBeneficiary);
        registry.rate(secondDealId, 4, "Second deal rating");

        // Assert - Both deals should have separate reviews
        (, , uint8 firstCustomerRating, string memory firstCustomerReview) = registry.dealReviews(dealId);
        (, , uint8 secondCustomerRating, string memory secondCustomerReview) = registry.dealReviews(secondDealId);

        assertEq(firstCustomerRating, 5, "First deal rating should be 5");
        assertEq(firstCustomerReview, "First deal rating", "First review should match");
        assertEq(secondCustomerRating, 4, "Second deal rating should be 4");
        assertEq(secondCustomerReview, "Second deal rating", "Second review should match");
    }

    function test_rate_differentServices() public {
        // Arrange - Create second service and deal
        vm.startPrank(anotherTasker);
        registry.addService("Second Service");
        registry.createDeal(1, DEAL_PRICE, beneficiary, 1 days, "second-service-deal");
        vm.stopPrank();

        // Act - Rate both deals
        vm.prank(beneficiary);
        registry.rate(0, 5, "Rating for first service"); // First deal
        vm.prank(beneficiary);
        registry.rate(1, 3, "Rating for second service"); // Second deal

        // Assert - Ratings should be separate for each deal
        (, , uint8 deal0Rating, string memory deal0Review) = registry.dealReviews(0);
        (, , uint8 deal1Rating, string memory deal1Review) = registry.dealReviews(1);

        assertEq(deal0Rating, 5, "First deal rating should be 5");
        assertEq(deal0Review, "Rating for first service", "First deal review should match");
        assertEq(deal1Rating, 3, "Second deal rating should be 3");
        assertEq(deal1Review, "Rating for second service", "Second deal review should match");
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_rate_doesNotAffectDealData() public {
        // Arrange
        (
            uint40 originalDealId,
            uint40 originalServiceId,
            address originalBeneficiary,
            uint256 originalAgreementId,
            uint256 originalPrice
        ) = registry.deals(dealId);

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, 5, "Rating should not affect deal data");

        // Assert - Deal data should be unchanged
        (
            uint40 finalDealId,
            uint40 finalServiceId,
            address finalBeneficiary,
            uint256 finalAgreementId,
            uint256 finalPrice
        ) = registry.deals(dealId);

        assertEq(finalDealId, originalDealId, "Deal ID should not change");
        assertEq(finalServiceId, originalServiceId, "Service ID should not change");
        assertEq(finalBeneficiary, originalBeneficiary, "Beneficiary should not change");
        assertEq(finalAgreementId, originalAgreementId, "Agreement ID should not change");
        assertEq(finalPrice, originalPrice, "Price should not change");
    }

    function test_rate_doesNotAffectUserStakes() public {
        // Arrange
        (, uint256 taskerStakeBefore) = registry.users(tasker);
        (, uint256 beneficiaryStakeBefore) = registry.users(beneficiary);

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, 5, "Rating should not affect stakes");

        // Assert - Stakes should be unchanged
        (, uint256 taskerStakeAfter) = registry.users(tasker);
        (, uint256 beneficiaryStakeAfter) = registry.users(beneficiary);

        assertEq(taskerStakeAfter, taskerStakeBefore, "Tasker stake should not change");
        assertEq(beneficiaryStakeAfter, beneficiaryStakeBefore, "Beneficiary stake should not change");
    }

    /*//////////////////////////////////////////////////////////////
                            GAS TESTING
    //////////////////////////////////////////////////////////////*/

    function test_rate_gasConsumption() public {
        // Arrange
        uint8 rating = 5;
        string memory review = "Gas consumption test review";

        // Act & Assert - Log gas usage
        vm.prank(beneficiary);
        registry.rate(dealId, rating, review);
    }
}
