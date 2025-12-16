// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEscrow} from "@kleros/escrow-v2/interfaces/IEscrow.sol";
import {Transaction, Status, IERC20 as EscrowIERC20} from "@kleros/escrow-v2/interfaces/Types.sol";

contract MockEscrow is IEscrow, IERC20 {
    uint256 private _mockAgreementId;

    mapping(uint256 => Transaction) internal _transactions;
    mapping(uint256 => uint256) internal _disputeIDtoTransactionID;

    // IEscrow methods
    function createERC20Transaction(
        uint256 _amount,
        IERC20 _token,
        uint256 _deadline,
        string memory,
        address payable _buyer,
        address payable _seller
    ) external returns (uint256 transactionID) {
        transactionID = ++_mockAgreementId;
        _transactions[transactionID] = Transaction({
            buyer: _buyer,
            seller: _seller,
            amount: _amount,
            settlementBuyer: 0,
            settlementSeller: 0,
            deadline: _deadline,
            disputeID: 0,
            buyerFee: 0,
            sellerFee: 0,
            lastFeePaymentTime: 0,
            status: Status.NoDispute,
            token: EscrowIERC20(address(_token))
        });
    }

    function createNativeTransaction(
        uint256 _deadline,
        string memory,
        address payable _buyer,
        address payable _seller
    ) external payable returns (uint256 transactionID) {
        transactionID = ++_mockAgreementId;
        _transactions[transactionID] = Transaction({
            buyer: _buyer,
            seller: _seller,
            amount: msg.value,
            settlementBuyer: 0,
            settlementSeller: 0,
            deadline: _deadline,
            disputeID: 0,
            buyerFee: 0,
            sellerFee: 0,
            lastFeePaymentTime: 0,
            status: Status.NoDispute,
            token: EscrowIERC20(address(0))
        });
    }

    function pay(uint256, uint256) external pure {}
    function reimburse(uint256, uint256) external pure {}
    function executeTransaction(uint256) external pure {}
    function reimburseTransaction(uint256) external pure {}
    function proposeSettlement(uint256, uint256) external pure {}
    function acceptSettlement(uint256) external pure {}
    function payArbitrationFeeByBuyer(uint256) external payable {}
    function payArbitrationFeeBySeller(uint256) external payable {}
    function timeOutByBuyer(uint256) external pure {}
    function timeOutBySeller(uint256) external pure {}

    function arbitrableTransactionStatus(uint256) external pure returns (uint8) {
        return 0;
    }

    function getTransactionCount() external pure returns (uint256) {
        return 0;
    }

    function transactions(uint256 _transactionID)
        external
        view
        returns (
            address payable buyer,
            address payable seller,
            uint256 amount,
            uint256 settlementBuyer,
            uint256 settlementSeller,
            uint256 deadline,
            uint256 disputeID,
            uint256 buyerFee,
            uint256 sellerFee,
            uint256 lastFeePaymentTime,
            Status status,
            EscrowIERC20 token
        )
    {
        Transaction storage t = _transactions[_transactionID];
        return (
            t.buyer,
            t.seller,
            t.amount,
            t.settlementBuyer,
            t.settlementSeller,
            t.deadline,
            t.disputeID,
            t.buyerFee,
            t.sellerFee,
            t.lastFeePaymentTime,
            t.status,
            t.token
        );
    }

    function disputeIDtoTransactionID(uint256 _disputeID) external view returns (uint256) {
        return _disputeIDtoTransactionID[_disputeID];
    }

    // IERC20 methods
    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
}
