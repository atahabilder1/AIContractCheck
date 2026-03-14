// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    uint256 public amount;
    bool public delivered;

    event FundsDeposited(address indexed buyer, uint256 amount);
    event DeliveryConfirmed();

    constructor(address _buyer, address _seller) {
        buyer = _buyer;
        seller = _seller;
    }

    function depositFunds() external payable {
        require(msg.sender == buyer, "Only the buyer can deposit funds");
        require(amount == 0, "Funds have already been deposited");
        amount = msg.value;
        emit FundsDeposited(buyer, amount);
    }

    function confirmDelivery() external {
        require(msg.sender == seller, "Only the seller can confirm delivery");
        require(!delivered, "Delivery has already been confirmed");
        delivered = true;
        emit DeliveryConfirmed();
    }

    function withdrawFunds() external {
        require(delivered, "Delivery must be confirmed before withdrawal");
        require(msg.sender == seller || msg.sender == buyer, "Only the buyer or seller can withdraw funds");
        if (msg.sender == seller) {
            (bool success, ) = seller.call{value: amount}("");
            require(success, "Transfer to seller failed");
        } else {
            (bool success, ) = buyer.call{value: amount}("");
            require(success, "Transfer to buyer failed");
        }
    }
}