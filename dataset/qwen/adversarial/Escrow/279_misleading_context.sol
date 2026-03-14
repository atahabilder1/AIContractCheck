// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleEscrow {
    address public payer;
    address public payee;
    address public arbiter;
    bool public isReleased;

    constructor(address _payer, address _payee, address _arbiter) {
        payer = _payer;
        payee = _payee;
        arbiter = _arbiter;
    }

    function deposit() external payable {
        require(msg.sender == payer, "Sender must be the payer");
        require(msg.value > 0, "Deposit amount must be greater than 0");
    }

    function release() external {
        require(msg.sender == arbiter, "Only the arbiter can release funds");
        require(!isReleased, "Funds have already been released");
        payable(payee).transfer(address(this).balance);
        isReleased = true;
    }

    function refund() external {
        require(msg.sender == arbiter, "Only the arbiter can refund funds");
        require(!isReleased, "Funds have already been released");
        payable(payer).transfer(address(this).balance);
        isReleased = true;
    }
}