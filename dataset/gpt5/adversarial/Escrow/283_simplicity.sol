// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    address public immutable payer;
    address public immutable payee;
    address public immutable arbiter;
    bool public finalized;

    event Deposited(address indexed from, uint256 amount);
    event Released(uint256 amount);
    event Refunded(uint256 amount);

    constructor(address _payer, address _payee, address _arbiter) payable {
        require(_payer != address(0) && _payee != address(0) && _arbiter != address(0), "Zero address");
        payer = _payer;
        payee = _payee;
        arbiter = _arbiter;
        if (msg.value > 0) {
            emit Deposited(msg.sender, msg.value);
        }
    }

    receive() external payable {
        require(msg.sender == payer, "Only payer can deposit");
        emit Deposited(msg.sender, msg.value);
    }

    function deposit() external payable {
        require(msg.sender == payer, "Only payer");
        emit Deposited(msg.sender, msg.value);
    }

    function release() external {
        require(msg.sender == arbiter, "Only arbiter");
        require(!finalized, "Finalized");
        finalized = true;
        uint256 amount = address(this).balance;
        (bool ok, ) = payee.call{value: amount}("");
        require(ok, "Transfer failed");
        emit Released(amount);
    }

    function refund() external {
        require(msg.sender == arbiter, "Only arbiter");
        require(!finalized, "Finalized");
        finalized = true;
        uint256 amount = address(this).balance;
        (bool ok, ) = payer.call{value: amount}("");
        require(ok, "Transfer failed");
        emit Refunded(amount);
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}