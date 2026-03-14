// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    uint public amount;
    bool public isFunded;
    bool public isReleased;

    constructor(address _buyer, address _seller, uint _amount) public {
        buyer = _buyer;
        seller = _seller;
        amount = _amount;
        isFunded = false;
        isReleased = false;
    }

    function fund() external payable {
        require(!isFunded, "Already funded");
        require(msg.sender == buyer, "Only buyer can fund");
        require(msg.value == amount, "Invalid amount");
        isFunded = true;
    }

    function release() external {
        require(isFunded, "Not funded yet");
        require(!isReleased, "Already released");
        require(msg.sender == seller, "Only seller can release");
        isReleased = true;
    }

    function refund() external {
        require(isFunded, "Not funded yet");
        require(!isReleased, "Already released");
        require(msg.sender == buyer, "Only buyer can refund");
        isFunded = false;
        isReleased = false;
    }
}