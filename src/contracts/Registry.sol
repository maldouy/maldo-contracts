// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRegistry} from "../interfaces/IRegistry.sol";
import {IEscrow} from "@kleros/escrow-v2/interfaces/IEscrow.sol";
import {Badges} from "./Badges.sol";
import {IDisputeResolver} from "../interfaces/IDisputeResolver.sol";
import {IEscrowCustomBuyer} from "../interfaces/IEscrowCustomBuyer.sol";

/// @title Registry
contract Registry is IRegistry, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum allowed rating value
    uint8 public constant MAX_RATING = 5;

    /*//////////////////////////////////////////////////////////////
                             IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The token that is used to stake and unstake
    IERC20 public immutable token;

    /// @notice The escrow contract
    IEscrow public immutable escrow;

    /// @notice The badges contract
    Badges public immutable badges;

    /*//////////////////////////////////////////////////////////////
                             STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps wallet addresses to user
    mapping(address _wallet => User _user) public users;

    /// @notice Array of services
    Service[] public services;

    /// @notice Array of deals
    Deal[] public deals;

    /// @notice Maps service ids to an array of ratings
    mapping(uint40 _serviceId => Rating[] _ratings) public ratings;

    /// @notice Address of the dispute resolver
    address public disputeResolver;

    constructor(address _token, address _badges, address _escrow) Ownable(msg.sender) {
        if (_token == address(0) || _badges == address(0) || _escrow == address(0)) {
            revert InvalidConstructorParams();
        }
        token = ERC20(_token);
        badges = Badges(_badges);
        escrow = IEscrow(_escrow);
    }

    /// @inheritdoc IRegistry
    function setProfile(string calldata _profile) external {
        users[msg.sender].profile = _profile;

        emit ProfileSet(msg.sender);
    }

    /// @inheritdoc IRegistry
    function addService(string calldata _description) external {
        uint40 serviceId = uint40(services.length);

        services.push(Service({id: serviceId, tasker: msg.sender, description: _description}));

        emit ServiceCreated(serviceId);
    }

    /// @inheritdoc IRegistry
    function updateService(uint40 _serviceId, string calldata _description) external onlyServiceOwner(_serviceId) {
        Service storage service = services[_serviceId];
        service.description = _description;

        emit ServiceUpdated(_serviceId, _description);
    }

    /// @inheritdoc IRegistry
    function createDeal(
        uint40 _serviceId,
        uint256 _price,
        address _beneficiary,
        uint256 _duration,
        string calldata _agreementURI
    ) external onlyServiceOwner(_serviceId) {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();

        uint40 nextDealId = uint40(deals.length);

        uint256 agreementId = _createEscrowAgreement(_beneficiary, _price, _duration, _agreementURI);

        deals.push(
            Deal({
                id: nextDealId,
                serviceId: _serviceId,
                price: _price,
                beneficiary: _beneficiary,
                agreementId: agreementId
            })
        );

        emit DealCreated(nextDealId);
    }

    /// @inheritdoc IRegistry
    function rate(uint40 _dealId, uint8 _rating, string calldata _review) external {
        if (_dealId >= deals.length) revert InvalidDealId();
        if (_rating > MAX_RATING) revert InvalidRating();

        if (deals[_dealId].beneficiary != msg.sender && services[deals[_dealId].serviceId].tasker != msg.sender) {
            revert Unauthorized();
        }

        // add review to the service
        ratings[deals[_dealId].serviceId].push(Rating({reviewer: msg.sender, rating: _rating, review: _review}));

        emit Rated(_dealId, _rating);
    }

    /// @inheritdoc IRegistry
    function dispute(uint40 _serviceId) external {
        if (_serviceId >= services.length) revert InvalidServiceId();
        if (disputeResolver == address(0)) revert DisputeResolverNotSet();

        IDisputeResolver(disputeResolver).dispute(_serviceId);

        emit Disputed(_serviceId);
    }

    /// @inheritdoc IRegistry
    function setDisputeResolver(address _disputeResolver) external onlyOwner {
        if (_disputeResolver == address(0)) revert InvalidDisputeResolver();

        disputeResolver = _disputeResolver;

        emit DisputeResolverSet(_disputeResolver);
    }

    // View functions

    /// @inheritdoc IRegistry
    function servicesCount() external view returns (uint256) {
        return services.length;
    }

    /// @inheritdoc IRegistry
    function dealsCount() external view returns (uint256) {
        return deals.length;
    }

    // Escrow functions

    function _createEscrowAgreement(
        address _beneficiary,
        uint256 _amount,
        uint256 _duration,
        string calldata _agreementURI
    ) internal returns (uint256 _agreementId) {
        _agreementId = IEscrowCustomBuyer(address(escrow))
            .createERC20TransactionCustomBuyer(
                _amount,
                IERC20(address(token)),
                block.timestamp + _duration,
                _agreementURI,
                payable(_beneficiary),
                payable(msg.sender)
            );
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures the caller is the owner of the service
    /// @param _serviceId ID of the service to check ownership
    modifier onlyServiceOwner(uint40 _serviceId) {
        if (_serviceId >= services.length) revert InvalidServiceId();
        if (services[_serviceId].tasker != msg.sender) revert Unauthorized();
        _;
    }
}
