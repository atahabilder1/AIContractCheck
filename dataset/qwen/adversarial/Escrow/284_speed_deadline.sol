// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    address public arbiter;
    bool public isApproved;
    bool public isRefunded;

    constructor(address _buyer, address _seller, address _arbiter) {
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        isApproved = false;
        isRefunded = false;
    }

    function deposit() external payable {
        require(msg.sender == buyer, "Only the buyer can deposit funds");
    }

    function approve() external {
        require(msg.sender == arbiter, "Only the arbiter can approve");
        require(!isApproved, "Payment already approved");
        require(!isRefunded, "Payment already refunded");
        isApproved = true;
        payable(seller).transfer(address(this).balance);
    }

    function refund() external {
        require(msg.sender == arbiter, "Only the arbiter can refund");
        require(!isApproved, "Payment already approved");
        require(!isRefunded, "Payment already refunded");
        isRefunded = true;
        payable(buyer).transfer(address(this).balance);
    }
}