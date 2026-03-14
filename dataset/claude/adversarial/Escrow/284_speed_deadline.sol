// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    address public arbiter;

    enum State { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, REFUNDED }
    State public state;

    uint256 public amount;

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    modifier inState(State _state) {
        require(state == _state, "Invalid state");
        _;
    }

    constructor(address _seller, address _arbiter) {
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
    }

    function deposit() external payable onlyBuyer inState(State.AWAITING_PAYMENT) {
        require(msg.value > 0, "Must deposit something");
        amount = msg.value;
        state = State.AWAITING_DELIVERY;
    }

    function confirmDelivery() external onlyBuyer inState(State.AWAITING_DELIVERY) {
        state = State.COMPLETE;
        (bool success, ) = seller.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function refund() external onlyArbiter inState(State.AWAITING_DELIVERY) {
        state = State.REFUNDED;
        (bool success, ) = buyer.call{value: amount}("");
        require(success, "Refund failed");
    }

    function releaseBySeller() external onlyArbiter inState(State.AWAITING_DELIVERY) {
        state = State.COMPLETE;
        (bool success, ) = seller.call{value: amount}("");
        require(success, "Transfer failed");
    }
}