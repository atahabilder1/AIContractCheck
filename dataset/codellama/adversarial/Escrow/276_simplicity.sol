// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address payable public owner;
    address payable public buyer;
    address payable public seller;
    uint public amount;

    constructor(address payable _owner, address payable _buyer, address payable _seller, uint _amount) public {
        owner = _owner;
        buyer = _buyer;
        seller = _seller;
        amount = _amount;
    }

    function release() public {
        require(msg.sender == owner, "Only the owner can release the funds");
        seller.transfer(amount);
    }

    function refund() public {
        require(msg.sender == buyer, "Only the buyer can request a refund");
        buyer.transfer(amount);
    }
}