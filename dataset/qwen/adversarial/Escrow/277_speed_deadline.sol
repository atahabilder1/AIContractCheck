// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    address public arbiter;
    bool public isReleased;
    bool public isRefunded;

    constructor(address _seller, address _arbiter) {
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
    }

    function deposit() public payable {
        require(msg.sender == buyer, "Only the buyer can deposit funds.");
    }

    function releaseFunds() public {
        require(msg.sender == arbiter || msg.sender == buyer, "Only the arbiter or buyer can release funds.");
        require(!isReleased && !isRefunded, "Funds have already been released or refunded.");
        payable(seller).transfer(address(this).balance);
        isReleased = true;
    }

    function refundFunds() public {
        require(msg.sender == arbiter, "Only the arbiter can refund funds.");
        require(!isReleased && !isRefunded, "Funds have already been released or refunded.");
        payable(buyer).transfer(address(this).balance);
        isRefunded = true;
    }
}