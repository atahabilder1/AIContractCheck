// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    address public arbiter;
    uint public amount;
    uint public deadline;
    bool public isReleased;
    bool public isDisputed;

    enum State { AWAITING_PAYMENT, AWAITING_DELIVERY, DISPUTED, COMPLETE }
    State public state;

    event PaymentReceived(uint amount);
    event DeliveryConfirmed();
    event DisputeRaised();
    event DisputeResolved(bool inFavorOfSeller);
    event PaymentReleased(uint amount);
    event RefundIssued(uint amount);

    constructor(address _buyer, address _seller, address _arbiter, uint _amount, uint _deadline) {
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        amount = _amount;
        deadline = block.timestamp + _deadline;
        state = State.AWAITING_PAYMENT;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Not the buyer");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Not the seller");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Not the arbiter");
        _;
    }

    modifier inState(State _state) {
        require(state == _state, "Invalid state");
        _;
    }

    function deposit() external payable onlyBuyer inState(State.AWAITING_PAYMENT) {
        require(msg.value == amount, "Incorrect amount");
        emit PaymentReceived(amount);
        state = State.AWAITING_DELIVERY;
    }

    function confirmDelivery() external onlyBuyer inState(State.AWAITING_DELIVERY) {
        require(block.timestamp <= deadline, "Deadline passed");
        isReleased = true;
        state = State.COMPLETE;
        payable(seller).transfer(amount);
        emit PaymentReleased(amount);
    }

    function raiseDispute() external onlyBuyer inState(State.AWAITING_DELIVERY) {
        require(block.timestamp <= deadline, "Deadline passed");
        isDisputed = true;
        state = State.DISPUTED;
        emit DisputeRaised();
    }

    function resolveDispute(bool inFavorOfSeller) external onlyArbiter inState(State.DISPUTED) {
        if (inFavorOfSeller) {
            payable(seller).transfer(amount);
            emit PaymentReleased(amount);
        } else {
            payable(buyer).transfer(amount);
            emit RefundIssued(amount);
        }
        state = State.COMPLETE;
        emit DisputeResolved(inFavorOfSeller);
    }

    function partialRelease(uint _amount) external onlyArbiter inState(State.DISPUTED) {
        require(_amount <= amount, "Amount exceeds total");
        payable(seller).transfer(_amount);
        amount -= _amount;
        emit PaymentReleased(_amount);
        if (amount == 0) {
            state = State.COMPLETE;
        }
    }

    function refundIfExpired() external onlyBuyer inState(State.AWAITING_DELIVERY) {
        require(block.timestamp > deadline, "Deadline not passed");
        payable(buyer).transfer(amount);
        emit RefundIssued(amount);
        state = State.COMPLETE;
    }
}