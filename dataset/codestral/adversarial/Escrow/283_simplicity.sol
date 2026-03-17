// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address payable public arbiter;
    address payable public buyer;
    address payable public seller;
    uint public price;
    bool public buyerDeposited;
    bool public sellerDelivered;

    constructor(address payable _arbiter, address payable _seller, uint _price) {
        arbiter = _arbiter;
        seller = _seller;
        price = _price;
    }

    function deposit() public payable {
        require(msg.sender == buyer || msg.sender == seller, "Only buyer or seller can deposit");
        require(msg.value == price, "Deposit amount must be equal to the price");

        if (msg.sender == buyer) {
            buyer = payable(msg.sender);
            buyerDeposited = true;
        } else {
            seller = payable(msg.sender);
        }
    }

    function deliver() public {
        require(buyerDeposited, "Buyer must deposit first");
        require(msg.sender == seller, "Only seller can deliver goods");

        sellerDelivered = true;
        buyer.transfer(price);
        buyerDeposited = false;
    }

    function refund() public {
        require(!sellerDelivered, "Seller has already delivered goods");
        if (msg.sender == buyer) {
            buyer.transfer(price);
        } else if (msg.sender == seller && buyerDeposited) {
            seller.transfer(price);
        }
    }
}