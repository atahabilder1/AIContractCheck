// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address payable public buyer;
    address payable public seller;
    address payable public arbiter;
    uint public totalPrice;
    uint public escrowBalance;
    bool public buyerConfirmed;
    bool public sellerConfirmed;
    bool public arbiterConfirmed;

    constructor(address payable _buyer, address payable _seller, address payable _arbiter, uint _totalPrice) public {
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        totalPrice = _totalPrice;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only the buyer can perform this action");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only the seller can perform this action");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only the arbiter can perform this action");
        _;
    }

    function deposit(uint amount) public onlyBuyer {
        require(amount > 0, "Deposit amount must be greater than 0");
        require(amount <= totalPrice, "Deposit amount exceeds total price");
        escrowBalance += amount;
    }

    function release() public onlySeller {
        require(buyerConfirmed && sellerConfirmed && arbiterConfirmed, "Not all parties have confirmed the release");
        escrowBalance = 0;
    }

    function refund() public onlyBuyer {
        require(buyerConfirmed && sellerConfirmed && arbiterConfirmed, "Not all parties have confirmed the refund");
        escrowBalance = 0;
    }

    function buyerConfirm() public onlyBuyer {
        buyerConfirmed = true;
    }

    function sellerConfirm() public onlySeller {
        sellerConfirmed = true;
    }

    function arbiterConfirm() public onlyArbiter {
        arbiterConfirmed = true;
    }
}