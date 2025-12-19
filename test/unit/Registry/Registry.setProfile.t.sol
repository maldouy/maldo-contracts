// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "../../../src/contracts/Registry.sol";
import {MockToken} from "../../mocks/MockToken.sol";
import {MockEscrow} from "../../mocks/MockEscrow.sol";
import {Badges} from "../../../src/contracts/Badges.sol";
import {IRegistry} from "../../../src/interfaces/IRegistry.sol";

contract RegistrySetProfileTest is Test {
    // Contract instances
    Registry public registry;
    MockToken public token;
    MockEscrow public escrow;
    Badges public badges;

    // Test users
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // Events to test
    event ProfileSet(address _user);

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
        user1 = makeAddr("User1");
        user2 = makeAddr("User2");
        user3 = makeAddr("User3");
    }

    /*//////////////////////////////////////////////////////////////
                             SUCCESS CASES
    //////////////////////////////////////////////////////////////*/

    function test_setProfile_success() public {
        // Arrange
        string memory profileData = "https://ipfs.io/profile/user1";

        // Act & Assert - Expect event emission
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(profileData);

        // Verify state change
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, profileData, "Profile should be stored correctly");
    }

    function test_setProfile_emptyString() public {
        // Arrange
        string memory emptyProfile = "";

        // Act & Assert
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(emptyProfile);

        // Verify state change
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, emptyProfile, "Empty profile should be stored correctly");
    }

    function test_setProfile_updateExistingProfile() public {
        // Arrange - Set initial profile
        string memory initialProfile = "Initial profile data";
        string memory updatedProfile = "Updated profile information";

        // Set initial profile
        vm.prank(user1);
        registry.setProfile(initialProfile);

        // Verify initial state
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, initialProfile, "Initial profile should be stored");

        // Act & Assert - Update profile
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(updatedProfile);

        // Verify updated state
        (string memory finalProfile,) = registry.users(user1);
        assertEq(finalProfile, updatedProfile, "Profile should be updated correctly");
    }

    function test_setProfile_multipleUsers() public {
        // Arrange
        string memory profile1 = "User 1 profile";
        string memory profile2 = "User 2 profile";
        string memory profile3 = "User 3 profile";

        // Act - Each user sets their profile
        vm.prank(user1);
        registry.setProfile(profile1);

        vm.prank(user2);
        registry.setProfile(profile2);

        vm.prank(user3);
        registry.setProfile(profile3);

        // Assert - Verify each profile is stored correctly
        (string memory storedProfile1,) = registry.users(user1);
        (string memory storedProfile2,) = registry.users(user2);
        (string memory storedProfile3,) = registry.users(user3);

        assertEq(storedProfile1, profile1, "User1 profile should be correct");
        assertEq(storedProfile2, profile2, "User2 profile should be correct");
        assertEq(storedProfile3, profile3, "User3 profile should be correct");
    }

    function test_setProfile_longProfileData() public {
        // Arrange - Create a long profile string
        string memory longProfile = string(
            abi.encodePacked(
                "This is a very long profile description that contains lots of information ",
                "about the user including their skills, experience, background, and other ",
                "relevant details that might be useful for potential clients or collaborators. ",
                "The profile might include IPFS hashes, JSON metadata, or other structured data ",
                "that represents a comprehensive user profile in a decentralized marketplace."
            )
        );

        // Act & Assert
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(longProfile);

        // Verify state change
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, longProfile, "Long profile should be stored correctly");
    }

    function test_setProfile_specialCharacters() public {
        // Arrange - Profile with special characters (ASCII only for compatibility)
        string memory specialProfile = "Profile with special chars: @#$%^&*()_+-=[]{}|;:,.<>?/~`";

        // Act & Assert
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(specialProfile);

        // Verify state change
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, specialProfile, "Profile with special characters should be stored");
    }

    function test_setProfile_jsonFormat() public {
        // Arrange - JSON-formatted profile
        string memory jsonProfile = '{"name":"John Doe","skills":["Solidity","JavaScript"],"rating":4.8}';

        // Act & Assert
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(jsonProfile);

        // Verify state change
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, jsonProfile, "JSON profile should be stored correctly");
    }

    function test_setProfile_ipfsHash() public {
        // Arrange - IPFS hash format
        string memory ipfsProfile = "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";

        // Act & Assert
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(ipfsProfile);

        // Verify state change
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, ipfsProfile, "IPFS hash profile should be stored correctly");
    }

    /*//////////////////////////////////////////////////////////////
                              EVENT TESTING
    //////////////////////////////////////////////////////////////*/

    function test_setProfile_emitsProfileSetEvent() public {
        // Arrange
        string memory profileData = "Test profile for event";

        // Assert - Check event emission with correct parameters
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        // Act
        vm.prank(user1);
        registry.setProfile(profileData);
    }

    function test_setProfile_emitsEventOnUpdate() public {
        // Arrange - Set initial profile
        vm.prank(user1);
        registry.setProfile("Initial profile");

        // Assert - Event should be emitted on update too
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        // Act - Update profile
        vm.prank(user1);
        registry.setProfile("Updated profile");
    }

    function test_setProfile_emitsEventForDifferentUsers() public {
        // Arrange
        string memory profile = "Test profile";

        // Assert & Act - Each user should emit their own event
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);
        vm.prank(user1);
        registry.setProfile(profile);

        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user2);
        vm.prank(user2);
        registry.setProfile(profile);
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_setProfile_doesNotAffectStake() public {
        // Arrange - Setup user
        token.mint(user1, 1000 ether);

        // Verify initial stake (should be 0 since stake/unstake removed)
        (, uint256 initialStake) = registry.users(user1);
        assertEq(initialStake, 0, "Initial stake should be 0");

        // Act - Set profile
        vm.prank(user1);
        registry.setProfile("Test profile");

        // Assert - Stake field should remain unchanged at 0
        (, uint256 finalStake) = registry.users(user1);
        assertEq(finalStake, initialStake, "Stake field should not be affected by profile setting");
    }

    function test_setProfile_doesNotAffectOtherUsers() public {
        // Arrange - Set profiles for multiple users
        vm.prank(user1);
        registry.setProfile("User 1 profile");

        vm.prank(user2);
        registry.setProfile("User 2 profile");

        // Act - User 1 updates their profile
        vm.prank(user1);
        registry.setProfile("User 1 updated profile");

        // Assert - User 2's profile should be unchanged
        (string memory user1Profile,) = registry.users(user1);
        (string memory user2Profile,) = registry.users(user2);

        assertEq(user1Profile, "User 1 updated profile", "User 1 profile should be updated");
        assertEq(user2Profile, "User 2 profile", "User 2 profile should be unchanged");
    }

    function test_setProfile_multipleUpdatesInSameTransaction() public {
        // Note: This test verifies that we can call setProfile multiple times
        // but each call is in a separate transaction due to vm.prank behavior

        string memory profile1 = "First profile";
        string memory profile2 = "Second profile";
        string memory profile3 = "Third profile";

        // Act - Multiple profile updates
        vm.prank(user1);
        registry.setProfile(profile1);

        vm.prank(user1);
        registry.setProfile(profile2);

        vm.prank(user1);
        registry.setProfile(profile3);

        // Assert - Only the last profile should be stored
        (string memory finalProfile,) = registry.users(user1);
        assertEq(finalProfile, profile3, "Final profile should be the last one set");
    }

    /*//////////////////////////////////////////////////////////////
                              EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_setProfile_resetToEmpty() public {
        // Arrange - Set initial non-empty profile
        vm.prank(user1);
        registry.setProfile("Initial profile");

        // Verify initial state
        (string memory initialProfile,) = registry.users(user1);
        assertTrue(bytes(initialProfile).length > 0, "Initial profile should not be empty");

        // Act - Reset to empty profile
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile("");

        // Assert - Profile should be empty
        (string memory finalProfile,) = registry.users(user1);
        assertEq(finalProfile, "", "Profile should be reset to empty");
    }

    function test_setProfile_sameProfileTwice() public {
        // Arrange
        string memory profileData = "Same profile data";

        // Act - Set profile twice
        vm.prank(user1);
        registry.setProfile(profileData);

        // Expect event emission on second call too
        vm.expectEmit(true, false, false, false);
        emit ProfileSet(user1);

        vm.prank(user1);
        registry.setProfile(profileData);

        // Assert - Profile should still be stored correctly
        (string memory storedProfile,) = registry.users(user1);
        assertEq(storedProfile, profileData, "Profile should be stored correctly even when set twice");
    }

    /*//////////////////////////////////////////////////////////////
                             GAS TESTING
    //////////////////////////////////////////////////////////////*/

    function test_setProfile_gasConsumption() public {
        // Arrange
        string memory profileData = "Profile for gas testing";

        // Act & Assert - Log gas usage for reference
        vm.prank(user1);
        registry.setProfile(profileData);
    }

    function test_setProfile_gasComparisonShortVsLong() public {
        // Arrange
        string memory shortProfile = "Short";
        string memory longProfile = string(
            abi.encodePacked(
                "This is a much longer profile that should consume more gas due to ",
                "the increased storage requirements and string handling operations"
            )
        );

        // Act - Test both scenarios (gas will be logged in test output)
        vm.prank(user1);
        registry.setProfile(shortProfile);

        vm.prank(user2);
        registry.setProfile(longProfile);

        // Assert - Both should succeed
        (string memory profile1,) = registry.users(user1);
        (string memory profile2,) = registry.users(user2);

        assertEq(profile1, shortProfile, "Short profile should be stored");
        assertEq(profile2, longProfile, "Long profile should be stored");
    }
}
