// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public arbiter;
    address public beneficiary;
    address public depositor;
    bool public isApproved;

    constructor(address _arbiter, address _beneficiary) {
        arbiter = _arbiter;
        beneficiary = _beneficiary;
        depositor = msg.sender;
    }

    function approvePayment() public {
        require(msg.sender == arbiter, "Only arbiter can approve the payment");
        isApproved = true;
        payable(beneficiary).transfer(address(this).balance);
    }

    function refundDepositor() public {
        require(msg.sender == depositor || msg.sender == arbiter, "Only depositor or arbiter can refund");
        require(!isApproved, "Payment has already been approved");
        payable(depositor).transfer(address(this).balance);
    }
}