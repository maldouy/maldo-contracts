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
    event Rated(uint40 _dealId, uint8 _rating);

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
        registry = new Registry(address(token), address(badges), address(escrow));

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

        // Assert - Check that rating was stored
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings.length, 1, "Should have 1 rating");
        assertEq(ratings[0].reviewer, beneficiary, "Reviewer should be beneficiary");
        assertEq(ratings[0].rating, rating, "Rating should match");
        assertEq(ratings[0].review, review, "Review should match");
    }

    function test_rate_beneficiaryMultipleRatings() public {
        // Arrange
        uint8 rating1 = 4;
        uint8 rating2 = 5;
        string memory review1 = "Good service";
        string memory review2 = "Updated: Great service!";

        // Act
        vm.startPrank(beneficiary);
        registry.rate(dealId, rating1, review1);
        registry.rate(dealId, rating2, review2);
        vm.stopPrank();

        // Assert - Both ratings should be stored
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings.length, 2, "Should have 2 ratings");
        assertEq(ratings[0].rating, rating1, "First rating should match");
        assertEq(ratings[1].rating, rating2, "Second rating should match");
        assertEq(ratings[0].review, review1, "First review should match");
        assertEq(ratings[1].review, review2, "Second review should match");
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

        // Assert
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings.length, 1, "Should have 1 rating");
        assertEq(ratings[0].reviewer, tasker, "Reviewer should be tasker");
        assertEq(ratings[0].rating, rating, "Rating should match");
        assertEq(ratings[0].review, review, "Review should match");
    }

    function test_rate_taskerMultipleRatings() public {
        // Arrange
        uint8 rating1 = 3;
        uint8 rating2 = 4;
        string memory review1 = "Client was okay";
        string memory review2 = "Client improved communication";

        // Act
        vm.startPrank(tasker);
        registry.rate(dealId, rating1, review1);
        registry.rate(dealId, rating2, review2);
        vm.stopPrank();

        // Assert
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings.length, 2, "Should have 2 ratings");
        assertEq(ratings[0].reviewer, tasker, "First reviewer should be tasker");
        assertEq(ratings[1].reviewer, tasker, "Second reviewer should be tasker");
    }

    /*//////////////////////////////////////////////////////////////
                      SUCCESS CASES - BOTH PARTIES
    //////////////////////////////////////////////////////////////*/

    function test_rate_bothPartiesCanRate() public {
        // Arrange
        uint8 beneficiaryRating = 5;
        uint8 taskerRating = 4;
        string memory beneficiaryReview = "Great service provider";
        string memory taskerReview = "Reliable client";

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, beneficiaryRating, beneficiaryReview);

        vm.prank(tasker);
        registry.rate(dealId, taskerRating, taskerReview);

        // Assert
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings.length, 2, "Should have 2 ratings total");

        // Find ratings by reviewer
        bool foundBeneficiaryRating = false;
        bool foundTaskerRating = false;

        for (uint256 i = 0; i < ratings.length; i++) {
            if (ratings[i].reviewer == beneficiary) {
                foundBeneficiaryRating = true;
                assertEq(ratings[i].rating, beneficiaryRating, "Beneficiary rating should match");
                assertEq(ratings[i].review, beneficiaryReview, "Beneficiary review should match");
            } else if (ratings[i].reviewer == tasker) {
                foundTaskerRating = true;
                assertEq(ratings[i].rating, taskerRating, "Tasker rating should match");
                assertEq(ratings[i].review, taskerReview, "Tasker review should match");
            }
        }

        assertTrue(foundBeneficiaryRating, "Should find beneficiary rating");
        assertTrue(foundTaskerRating, "Should find tasker rating");
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

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit Rated(dealId, rating);

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, review);
    }

    function test_rate_emitsMultipleEvents() public {
        // Arrange
        uint8 rating1 = 4;
        uint8 rating2 = 5;

        // First event
        vm.expectEmit(true, false, false, true);
        emit Rated(dealId, rating1);
        vm.prank(beneficiary);
        registry.rate(dealId, rating1, "First rating");

        // Second event
        vm.expectEmit(true, false, false, true);
        emit Rated(dealId, rating2);
        vm.prank(tasker);
        registry.rate(dealId, rating2, "Second rating");
    }

    /*//////////////////////////////////////////////////////////////
                              EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_rate_allRatingValues() public {
        // Test all valid rating values (0-5)
        vm.startPrank(beneficiary);

        for (uint8 rating = 0; rating <= 5; rating++) {
            string memory review = string(abi.encodePacked("Rating: ", uint256(rating)));
            registry.rate(dealId, rating, review);
        }

        vm.stopPrank();

        // Assert all ratings were stored
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings.length, 6, "Should have 6 ratings (0-5)");

        for (uint8 i = 0; i <= 5; i++) {
            assertEq(ratings[i].rating, i, "Rating should match expected value");
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

    function test_rate_emptyReview() public {
        // Arrange
        uint8 rating = 5;
        string memory emptyReview = "";

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, emptyReview);

        // Assert
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings[0].review, emptyReview, "Should accept empty review");
        assertEq(ratings[0].rating, rating, "Rating should still be set");
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
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings[0].review, longReview, "Should accept long review");
    }

    function test_rate_specialCharactersInReview() public {
        // Arrange
        uint8 rating = 5;
        string memory specialReview = "Great service! 5/5 stars - 100% satisfied!";

        // Act
        vm.prank(beneficiary);
        registry.rate(dealId, rating, specialReview);

        // Assert
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings[0].review, specialReview, "Should accept special characters");
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

        // Assert - Both ratings should be for the same service
        IRegistry.Rating[] memory ratings = getServiceRatings(serviceId);
        assertEq(ratings.length, 2, "Should have 2 ratings for the service");
        assertEq(ratings[0].reviewer, beneficiary, "First rating from original beneficiary");
        assertEq(ratings[1].reviewer, anotherBeneficiary, "Second rating from another beneficiary");
    }

    function test_rate_differentServices() public {
        // Arrange - Create second service and deal
        vm.startPrank(anotherTasker);
        registry.addService("Second Service");
        registry.createDeal(1, DEAL_PRICE, beneficiary, 1 days, "second-service-deal");
        vm.stopPrank();

        // Act - Rate both services
        vm.prank(beneficiary);
        registry.rate(0, 5, "Rating for first service"); // First deal
        vm.prank(beneficiary);
        registry.rate(1, 3, "Rating for second service"); // Second deal

        // Assert - Ratings should be separate for each service
        IRegistry.Rating[] memory service1Ratings = getServiceRatings(0);
        IRegistry.Rating[] memory service2Ratings = getServiceRatings(1);

        assertEq(service1Ratings.length, 1, "First service should have 1 rating");
        assertEq(service2Ratings.length, 1, "Second service should have 1 rating");
        assertEq(service1Ratings[0].rating, 5, "First service rating should be 5");
        assertEq(service2Ratings[0].rating, 3, "Second service rating should be 3");
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
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getServiceRatings(uint40 _serviceId) internal view returns (IRegistry.Rating[] memory) {
        // This is a workaround to access the ratings mapping
        // In a real scenario, you might need getter functions in the contract
        try registry.ratings(_serviceId, 0) returns (address reviewer, uint8 rating, string memory review) {
            // Count how many ratings exist
            uint256 count = 0;
            while (true) {
                try registry.ratings(_serviceId, count) returns (address, uint8, string memory) {
                    count++;
                } catch {
                    break;
                }
            }

            // Create array and populate it
            IRegistry.Rating[] memory ratings = new IRegistry.Rating[](count);
            for (uint256 i = 0; i < count; i++) {
                (address rev, uint8 rat, string memory rev_text) = registry.ratings(_serviceId, i);
                ratings[i] = IRegistry.Rating(rev, rat, rev_text);
            }
            return ratings;
        } catch {
            // No ratings exist, return empty array
            return new IRegistry.Rating[](0);
        }
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
