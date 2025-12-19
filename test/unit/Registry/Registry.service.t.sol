// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "../../../src/contracts/Registry.sol";
import {MockToken} from "../../mocks/MockToken.sol";
import {Badges} from "../../../src/contracts/Badges.sol";
import {MockEscrow} from "../../mocks/MockEscrow.sol";
import {IRegistry} from "../../../src/interfaces/IRegistry.sol";

contract RegistryServiceTest is Test {
    Registry public registry;
    MockToken public token;
    Badges public badges;
    MockEscrow public escrow;

    // Test users
    address public alice;
    address public bob;
    address public charlie;

    // Events to test
    event ServiceCreated(uint40 _serviceId);
    event ServiceUpdated(uint40 _serviceId, string _description);

    function setUp() public {
        // Deploy mock contracts
        token = new MockToken("TestToken", "TTK");
        badges = new Badges(address(this));
        escrow = new MockEscrow();

        // Deploy the registry
        registry = new Registry(address(token), address(escrow), address(this));

        // Create test users
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Mint tokens for testing
        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);
        token.mint(charlie, 1000 ether);
    }

    // addService tests
    function test_addService_successSingleService() public {
        // Arrange
        string memory description = "Testing service creation";

        // Act
        vm.prank(alice);
        registry.addService(description);

        // Assert - check the service was created with ID 0
        (uint40 id, address tasker, string memory desc) = registry.services(0);

        assertEq(id, 0, "Service ID should match");
        assertEq(tasker, alice, "Tasker should be the service creator");
        assertEq(desc, description, "Description should match input");
    }

    function test_addService_multipleServicesFromSameUser() public {
        // Arrange
        string memory desc1 = "First service";
        string memory desc2 = "Second service";

        // Act
        vm.prank(alice);
        registry.addService(desc1);

        vm.prank(alice);
        registry.addService(desc2);

        // Assert - verify both services were created with correct IDs
        (uint40 id1,,) = registry.services(0);
        (uint40 id2,,) = registry.services(1);
        assertEq(id1, 0, "First service ID should be 0");
        assertEq(id2, 1, "Second service ID should be 1");
    }

    function test_addService_multipleUsersServices() public {
        // Act
        vm.prank(alice);
        registry.addService("Alice's service");

        vm.prank(bob);
        registry.addService("Bob's service");

        vm.prank(charlie);
        registry.addService("Charlie's service");

        // Assert - verify services were created with incrementing IDs
        (uint40 id1,,) = registry.services(0);
        (uint40 id2,,) = registry.services(1);
        (uint40 id3,,) = registry.services(2);
        assertEq(id1, 0, "First service ID should be 0");
        assertEq(id2, 1, "Second service ID should be 1");
        assertEq(id3, 2, "Third service ID should be 2");
    }

    function test_addService_emitServiceCreatedEvent() public {
        // Arrange
        string memory description = "Event test service";

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit ServiceCreated(0);

        // Act
        vm.prank(alice);
        registry.addService(description);
    }

    function test_addService_emptyDescriptionAllowed() public {
        // Arrange
        string memory description = "";

        // Act
        vm.prank(alice);
        registry.addService(description);

        // Assert
        (,, string memory desc) = registry.services(0);
        assertEq(desc, description, "Empty description should be allowed");
    }

    function test_addService_longDescription() public {
        // Arrange
        string memory longDescription = string(
            abi.encodePacked(
                "This is a very long description that tests the limits of the service description. ",
                "It should be able to handle quite a bit of text without any issues. ",
                "The goal is to ensure that we can create services with substantial descriptive text. ",
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor ",
                "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud ",
                "exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
            )
        );

        // Act
        vm.prank(alice);
        registry.addService(longDescription);

        // Assert
        (,, string memory desc) = registry.services(0);
        assertEq(desc, longDescription, "Long description should be stored correctly");
    }

    // updateService tests
    function test_updateService_successByTasker() public {
        // Arrange
        vm.prank(alice);
        registry.addService("Original description");
        string memory updatedDescription = "Updated service description";

        // Act
        vm.prank(alice);
        registry.updateService(0, updatedDescription);

        // Assert
        (,, string memory desc) = registry.services(0);
        assertEq(desc, updatedDescription, "Service description should be updated");
    }

    function test_updateService_emitServiceUpdatedEvent() public {
        // Arrange
        vm.prank(alice);
        registry.addService("Original description");
        string memory updatedDescription = "Updated service description";

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit ServiceUpdated(0, updatedDescription);

        // Act
        vm.prank(alice);
        registry.updateService(0, updatedDescription);
    }

    function test_updateService_revertUnauthorizedUser() public {
        // Arrange
        vm.prank(alice);
        registry.addService("Alice's service");

        // Act & Assert
        vm.prank(bob);
        vm.expectRevert(IRegistry.Unauthorized.selector);
        registry.updateService(0, "Unauthorized update attempt");
    }

    function test_updateService_multipleUpdates() public {
        // Arrange
        vm.prank(alice);
        registry.addService("First description");

        // Act & Assert
        vm.prank(alice);
        registry.updateService(0, "Second description");

        vm.prank(alice);
        registry.updateService(0, "Third description");

        (,, string memory desc) = registry.services(0);
        assertEq(desc, "Third description", "Service should support multiple updates");
    }

    function test_updateService_revertNonExistentService() public {
        // Act & Assert
        vm.prank(alice);
        vm.expectRevert(IRegistry.InvalidServiceId.selector);
        registry.updateService(99, "Nonexistent service");
    }
}
