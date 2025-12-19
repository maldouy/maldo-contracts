// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Badges
/// @notice ERC1155 token contract for profile badges
contract Badges is ERC1155, Ownable, AccessControl, ReentrancyGuard {
    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role for minting badges
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role for managing badge metadata and creation
    bytes32 public constant BADGE_MANAGER_ROLE = keccak256("BADGE_MANAGER_ROLE");

    /// @notice Role for pausing functionality (if needed in future)
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Badge metadata structure
    /// @param name Human readable name of the badge
    /// @param description Description of what the badge represents
    /// @param creator Address of the badge creator
    struct Badge {
        string name;
        string description;
        address creator;
    }

    /// @notice Maps badge ID to its metadata
    mapping(uint256 badgeId => Badge badge) public badges;

    /// @notice Maps badge ID to current total supply
    mapping(uint256 badgeId => uint256 supply) public totalSupply;

    /// @notice Counter for the next badge ID
    uint256 public nextBadgeId;

    /// @notice Base URI for token metadata
    string private _baseTokenURI;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new badge type is created
    /// @param badgeId The ID of the created badge
    /// @param name The name of the badge
    event BadgeCreated(uint256 indexed badgeId, string name);

    /// @notice Emitted when badge metadata is updated
    /// @param badgeId The ID of the updated badge
    /// @param name The new name of the badge
    event BadgeMetadataUpdated(uint256 indexed badgeId, string name);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CannotTransfer();

    error InvalidParameters();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor
    /// @param admin Address that will have admin role
    /// @dev Sets up the contract with initial roles and URI
    /// @dev OpenZeppelin's Ownable already checks for address(0)
    constructor(address admin) ERC1155("") Ownable(admin) {
        // Grant roles to the admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BADGE_MANAGER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            BADGE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new badge type
    /// @param name Name of the badge
    /// @param description Description of the badge
    /// @return badgeId The ID of the newly created badge
    /// @dev Only addresses with BADGE_MANAGER_ROLE can create badges
    function createBadge(
        string calldata name,
        string calldata description
    ) external onlyRole(BADGE_MANAGER_ROLE) returns (uint256 badgeId) {
        if (bytes(name).length == 0) revert InvalidParameters();

        badgeId = nextBadgeId++;

        badges[badgeId] = Badge({name: name, description: description, creator: msg.sender});

        emit BadgeCreated(badgeId, name);
    }

    /// @notice Updates badge metadata
    /// @param badgeId ID of the badge to update
    /// @param name New name of the badge
    /// @param description New description of the badge
    function updateBadgeMetadata(
        uint256 badgeId,
        string calldata name,
        string calldata description
    ) external onlyRole(BADGE_MANAGER_ROLE) {
        Badge storage badge = badges[badgeId];
        badge.name = name;
        badge.description = description;

        emit BadgeMetadataUpdated(badgeId, name);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints a badge to an address
    /// @param to The address to mint the badge to
    /// @param id The ID of the badge to mint
    /// @param amount The amount of badges to mint
    function mint(address to, uint256 id, uint256 amount) external onlyRole(MINTER_ROLE) {
        totalSupply[id] += amount;
        _mint(to, id, amount, "");
    }

    /// @notice Mints a batch of badges to an address
    /// @param to The address to mint the badges to
    /// @param ids The IDs of the badges to mint
    /// @param amounts The amounts of badges to mint
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        for (uint256 i = 0; i < ids.length; ++i) {
            totalSupply[ids[i]] += amounts[i];
            _mint(to, ids[i], amounts[i], "");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Override to check transferability before transfers
    /// @param from Address sending the tokens
    /// @param to Address receiving the tokens
    /// @param id Token ID
    /// @param amount Amount being transferred
    /// @param data Additional data
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public override {
        // Allow minting (from = address(0)) and burning (to = address(0))
        if (from != address(0) && to != address(0)) {
            if (badges[id].creator != msg.sender) {
                revert CannotTransfer();
            }
        }

        super.safeTransferFrom(from, to, id, amount, data);
    }

    /// @notice Override to check transferability before batch transfers
    /// @param from Address sending the tokens
    /// @param to Address receiving the tokens
    /// @param ids Array of token IDs
    /// @param amounts Array of amounts
    /// @param data Additional data
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        // Allow minting (from = address(0)) and burning (to = address(0))
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 tokenId = ids[i];
                if (badges[tokenId].creator != msg.sender) {
                    revert CannotTransfer();
                }
            }
        }

        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the URI for a given token ID
    /// @param tokenId Token ID to get URI for
    /// @return tokenURI The URI for the given token ID
    function uri(uint256 tokenId) public pure override returns (string memory tokenURI) {
        return string(abi.encodePacked("https://api.badges.com/", tokenId.toString()));
    }

    /// @notice Checks if a user has earned a specific badge
    /// @param user Address to check
    /// @param badgeId Badge ID to check
    /// @return True if the user has the badge, false otherwise
    function hasBadge(address user, uint256 badgeId) external view returns (bool) {
        return balanceOf(user, badgeId) > 0;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
