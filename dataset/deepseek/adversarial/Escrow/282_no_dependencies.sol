// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    uint public price;
    bool public released;

    event FundsWithdrawn(uint amount);
    event FundsReleased();

    constructor(address _buyer, address _seller, uint _price) {
        buyer = _buyer;
        seller = _seller;
        price = _price;
        released = false;
    }

    function deposit() public payable {
        require(msg.sender == buyer, "Only buyer can deposit funds");
        require(msg.value == price, "Deposited amount must be equal to the price");
    }

    function release() public {
        require(msg.sender == seller, "Only seller can release funds");
        require(!released, "Funds have already been released");
        require(address(this).balance >= price, "Contract does not have enough funds to release");

        released = true;
        (bool success, ) = seller.call{value: address(this).balance}("");
        require(success, "Transfer failed");
        emit FundsReleased();
    }

    function withdraw() public {
        require(msg.sender == buyer, "Only buyer can withdraw funds");
        require(released, "Funds have not been released yet");
        require(address(this).balance >= price, "Contract does not have enough funds to withdraw");

        uint amount = address(this).balance;
        (bool success, ) = buyer.call{value: amount}("");
        require(success, "Transfer failed");
        emit FundsWithdrawn(amount);
    }
}