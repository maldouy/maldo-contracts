// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../../../src/contracts/Registry.sol";
import {IRegistry} from "../../../src/interfaces/IRegistry.sol";
import {Badges} from "../../../src/contracts/Badges.sol";
import {MockEscrow} from "../../mocks/MockEscrow.sol";
import {MockToken} from "../../mocks/MockToken.sol";

contract RegistryGettersTest is Test {
    Registry public registry;
    MockToken public token;
    Badges public badges;
    MockEscrow public escrow;

    address public deployer;
    address public tasker1;
    address public tasker2;
    address public user1;
    address public user2;

    function setUp() public {
        deployer = makeAddr("deployer");
        tasker1 = makeAddr("tasker1");
        tasker2 = makeAddr("tasker2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(deployer);
        token = new MockToken("Test", "TST");
        badges = new Badges(deployer);
        escrow = new MockEscrow();
        registry = new Registry(address(token), address(escrow), address(this));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            getToken TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getToken() public view {
        assertEq(address(registry.token()), address(token));
    }

    function test_escrow() public view {
        assertEq(address(registry.escrow()), address(escrow));
    }

    /*//////////////////////////////////////////////////////////////
                        servicesCount TESTS
    //////////////////////////////////////////////////////////////*/

    function test_servicesCount_Zero() public view {
        assertEq(registry.servicesCount(), 0);
    }

    function test_servicesCount_Single() public {
        vm.prank(tasker1);
        registry.addService("service 1");

        assertEq(registry.servicesCount(), 1);
    }

    function test_servicesCount_Multiple() public {
        vm.prank(tasker1);
        registry.addService("service 1");

        vm.prank(tasker2);
        registry.addService("service 2");

        vm.prank(tasker1);
        registry.addService("service 3");

        assertEq(registry.servicesCount(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                        dealsCount TESTS
    //////////////////////////////////////////////////////////////*/

    function test_dealsCount_Zero() public view {
        assertEq(registry.dealsCount(), 0);
    }

    function test_dealsCount_Single() public {
        // Setup: create service first
        vm.prank(tasker1);
        registry.addService("service 1");

        // Create deal
        vm.prank(tasker1);
        registry.createDeal(0, 100, user1, 1 days, "agreement1");

        assertEq(registry.dealsCount(), 1);
    }

    function test_dealsCount_Multiple() public {
        // Setup: create services first
        vm.prank(tasker1);
        registry.addService("service 1");

        // Create deals
        vm.prank(tasker1);
        registry.createDeal(0, 100, user1, 1 days, "agreement1");

        vm.prank(tasker1);
        registry.createDeal(0, 200, user2, 1 days, "agreement2");

        vm.prank(tasker1);
        registry.createDeal(0, 150, user1, 1 days, "agreement3");

        assertEq(registry.dealsCount(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                    ratings TESTS
    //////////////////////////////////////////////////////////////*/

    function test_dealReviews_Single() public {
        // Setup: create service and deal
        vm.prank(tasker1);
        registry.addService("service 1");

        vm.prank(tasker1);
        registry.createDeal(0, 100, user1, 1 days, "agreement");

        // Add rating from customer
        vm.prank(user1);
        registry.rate(0, 5, "excellent");

        // Access review through dealReviews mapping getter
        (uint8 taskerRating, string memory taskerReview, uint8 customerRating, string memory customerReview) =
            registry.dealReviews(0);
        assertEq(customerRating, 5);
        assertEq(customerReview, "excellent");
        assertEq(taskerRating, 0); // Tasker hasn't rated yet
        assertEq(bytes(taskerReview).length, 0);
    }

    function test_dealReviews_BothParties() public {
        // Setup: create service and deal
        vm.prank(tasker1);
        registry.addService("service 1");

        vm.prank(tasker1);
        registry.createDeal(0, 100, user1, 1 days, "agreement");

        // Add ratings from both parties
        vm.prank(user1);
        registry.rate(0, 5, "excellent");

        vm.prank(tasker1);
        registry.rate(0, 4, "good client");

        // Access both reviews through dealReviews mapping
        (uint8 taskerRating, string memory taskerReview, uint8 customerRating, string memory customerReview) =
            registry.dealReviews(0);

        // Verify customer review (from user1)
        assertEq(customerRating, 5);
        assertEq(customerReview, "excellent");

        // Verify tasker review (from tasker1)
        assertEq(taskerRating, 4);
        assertEq(taskerReview, "good client");
    }

    function test_dealReviews_MultipleDealsSeparateReviews() public {
        // Setup: create service and multiple deals
        vm.prank(tasker1);
        registry.addService("service 1");

        vm.prank(tasker1);
        registry.createDeal(0, 100, user1, 1 days, "agreement1");

        vm.prank(tasker1);
        registry.createDeal(0, 200, user2, 1 days, "agreement2");

        // Add ratings from different deals
        vm.prank(user1);
        registry.rate(0, 5, "excellent from deal 1");

        vm.prank(user2);
        registry.rate(1, 3, "okay from deal 2");

        // Verify each deal has its own separate review
        (,, uint8 deal0Rating, string memory deal0Review) = registry.dealReviews(0);
        assertEq(deal0Rating, 5);
        assertEq(deal0Review, "excellent from deal 1");

        (,, uint8 deal1Rating, string memory deal1Review) = registry.dealReviews(1);
        assertEq(deal1Rating, 3);
        assertEq(deal1Review, "okay from deal 2");
    }
}
