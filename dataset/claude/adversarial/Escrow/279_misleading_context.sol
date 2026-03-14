// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Escrow {
    enum State { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, REFUNDED }

    address public buyer;
    address public seller;
    address public arbiter;
    uint256 public amount;
    State public state;

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

    event Deposited(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);

    constructor(address _seller, address _arbiter) {
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
        state = State.AWAITING_PAYMENT;
    }

    function deposit() external payable onlyBuyer inState(State.AWAITING_PAYMENT) {
        require(msg.value > 0, "Must send ETH");
        amount = msg.value;
        state = State.AWAITING_DELIVERY;
        emit Deposited(msg.sender, msg.value);
    }

    function confirmDelivery() external onlyBuyer inState(State.AWAITING_DELIVERY) {
        state = State.COMPLETE;
        (bool sent, ) = seller.call{value: amount}("");
        require(sent, "Transfer failed");
        emit Released(seller, amount);
    }

    function refund() external onlyArbiter inState(State.AWAITING_DELIVERY) {
        state = State.REFUNDED;
        (bool sent, ) = buyer.call{value: amount}("");
        require(sent, "Transfer failed");
        emit Refunded(buyer, amount);
    }

    function releaseBySeller() external onlyArbiter inState(State.AWAITING_DELIVERY) {
        state = State.COMPLETE;
        (bool sent, ) = seller.call{value: amount}("");
        require(sent, "Transfer failed");
        emit Released(seller, amount);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}