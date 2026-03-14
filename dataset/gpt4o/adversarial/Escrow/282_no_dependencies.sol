// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public payer;
    address public payee;
    address public arbiter;
    uint256 public amount;
    bool public isFunded;
    bool public isReleased;

    event Funded(uint256 amount);
    event Released();

    modifier onlyPayer() {
        require(msg.sender == payer, "Only payer can call this function");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter can call this function");
        _;
    }

    modifier notReleased() {
        require(!isReleased, "Funds have already been released");
        _;
    }

    constructor(address _payee, address _arbiter) payable {
        require(msg.value > 0, "Amount must be greater than 0");
        payer = msg.sender;
        payee = _payee;
        arbiter = _arbiter;
        amount = msg.value;
        isFunded = true;
        isReleased = false;
        emit Funded(amount);
    }

    function releaseFunds() external onlyArbiter notReleased {
        require(isFunded, "Funds not available");
        isReleased = true;
        payable(payee).transfer(amount);
        emit Released();
    }

    function refund() external onlyPayer notReleased {
        require(isFunded, "Funds not available");
        isReleased = true;
        payable(payer).transfer(amount);
        emit Released();
    }
}