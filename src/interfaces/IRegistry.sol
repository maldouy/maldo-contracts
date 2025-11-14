// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDisputeResolver} from "./IDisputeResolver.sol";

/// @title IRegistry
interface IRegistry {
    /// @notice User structure
    /// @param profile Ideally an IPFS hash, for now simply a string
    /// @param stake Amount of tokens staked by the user
    struct User {
        string profile;
        uint256 stake;
    }

    /// @notice Service listing structure
    /// @dev
    /// @param id Unique identifier for the service
    /// @param tasker Address of the service provider
    /// @param description Ideally an IPFS hash, for now simply a string
    struct Service {
        uint40 id;
        address tasker;
        string description;
    }

    /// @notice Service rating structure
    /// @dev
    /// @param rating A numerical rating, between 0 to 5
    /// @param review Ideally an IPFS hash, for now simply a string
    struct Rating {
        address reviewer;
        uint8 rating;
        string review;
    }

    /// @notice Deal structure
    /// @dev
    /// @param id ID of the deal
    /// @param serviceId ID of the service
    /// @param beneficiary Address of the beneficiary
    /// @param agreementId Kleros escrow agreement ID
    /// @param price Price of the service
    struct Deal {
        uint40 id;
        uint40 serviceId;
        address beneficiary;
        uint256 agreementId;
        uint256 price;
    }

    //////////////////////////////////////////////////////
    /////////////////////// EVENTS ///////////////////////
    //////////////////////////////////////////////////////

    /// @notice Emitted when a user updates their profile
    /// @param _user Address of the user who updated their profile
    event ProfileSet(address _user);

    /// @notice Emitted when a new service is created
    /// @param _serviceId The new service's id
    event ServiceCreated(uint40 _serviceId);

    /// @notice Emitted when a service is updated
    /// @param _serviceId The updated service's id
    /// @param _description The new description of the service
    event ServiceUpdated(uint40 _serviceId, string _description);

    /// @notice Emitted when a deal is created
    /// @param _dealId The new deal's id
    event DealCreated(uint40 _dealId);

    /// @notice Emitted when a deal receives a rating
    /// @param _dealId The rated deal's id
    /// @param _rating The rating given
    event Rated(uint40 _dealId, uint8 _rating);

    /// @notice Emitted when a service rating is disputed
    /// @param _serviceId The disputed service's id
    event Disputed(uint40 _serviceId);

    /// @notice Emitted when the dispute resolver is set or updated
    /// @param disputeResolver The new dispute resolver address
    event DisputeResolverSet(address indexed disputeResolver);

    //////////////////////////////////////////////////////
    /////////////////////// ERRORS ///////////////////////
    //////////////////////////////////////////////////////

    /// @notice Error thrown when an invalid amount is provided
    error InvalidAmount();

    /// @notice Error thrown when user has insufficient staked tokens
    error InsufficientStake();

    /// @notice Error thrown when the caller is not authorized
    error Unauthorized();

    /// @notice Error thrown when dispute resolver is not set
    error DisputeResolverNotSet();

    /// @notice Thrown when the beneficiary address is zero
    error InvalidBeneficiary();

    /// @notice Thrown when constructor parameters are invalid (zero address)
    error InvalidConstructorParams();

    /// @notice Thrown when service ID doesn't exist
    error InvalidServiceId();

    /// @notice Thrown when deal ID doesn't exist
    error InvalidDealId();

    /// @notice Thrown when rating value is invalid (must be 0-5)
    error InvalidRating();

    /// @notice Thrown when dispute resolver address is invalid (zero address)
    error InvalidDisputeResolver();

    //////////////////////////////////////////////////////
    ////////////////////// FUNCTIONS /////////////////////
    //////////////////////////////////////////////////////

    /// @notice Sets or updates a user's profile
    /// @param _profile Ideally an IPFS hash, for now simply a string
    function setProfile(string calldata _profile) external;

    /// @notice Creates a new service listing
    /// @param _description Ideally an IPFS hash, for now simply a string
    function addService(string calldata _description) external;

    /// @notice Updates an existing service listing
    /// @param _serviceId ID of the service to update
    /// @param _description Ideally an IPFS hash, for now simply a string containing the new description
    function updateService(uint40 _serviceId, string calldata _description) external;

    /// @notice Submits a rating for a deal
    /// @param _dealId ID of the deal to rate
    /// @param _rating A numerical rating, between 0 to 5
    /// @param _review Ideally an IPFS hash, for now simply an arbitrary string
    function rate(uint40 _dealId, uint8 _rating, string calldata _review) external;

    /// @notice Initiates a dispute
    /// @dev
    /// @param _serviceId ID of the service with disputed rating
    function dispute(uint40 _serviceId) external;

    /// @notice Creates a deal for a service
    /// @param _serviceId ID of the service
    /// @param _price Price of the deal
    /// @param _beneficiary Address of the beneficiary
    /// @param _duration Duration in seconds for the escrow timeout
    /// @param _agreementURI URI for the agreement
    function createDeal(
        uint40 _serviceId,
        uint256 _price,
        address _beneficiary,
        uint256 _duration,
        string calldata _agreementURI
    ) external;

    /// @notice Sets the dispute resolver address
    /// @dev
    /// @param _disputeResolver The dispute resolver contract
    function setDisputeResolver(IDisputeResolver _disputeResolver) external;

    /// @notice Returns the token address used for deals and escrow
    /// @return _token the address of the token
    function token() external view returns (IERC20 _token);

    /// @notice Returns the total number of services created
    /// @return _count total count of services
    function servicesCount() external view returns (uint256 _count);

    /// @notice Returns the total number of deals created
    /// @return _count total count of deals
    function dealsCount() external view returns (uint256 _count);
}
