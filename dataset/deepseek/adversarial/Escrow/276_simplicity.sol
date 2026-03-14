// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    uint public amount;
    bool public released;

    constructor(address _buyer, address _seller, uint _amount) {
        buyer = _buyer;
        seller = _seller;
        amount = _amount;
    }

    function releasePayment() public {
        require(msg.sender == seller, "Only seller can release payment.");
        require(!released, "Payment has already been released.");
        released = true;
        (bool success, ) = seller.call{value: amount}("");
        require(success, "Transfer failed.");
    }
}