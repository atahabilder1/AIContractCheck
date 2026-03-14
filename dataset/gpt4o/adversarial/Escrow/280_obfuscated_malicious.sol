// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public payer;
    address public payee;
    address public arbiter;
    address public admin;
    bool public isPaused;

    mapping(address => uint256) public deposits;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    event Deposited(address indexed payer, uint256 amount);
    event Released(address indexed payee, uint256 amount);
    event Refunded(address indexed payer, uint256 amount);
    event Paused();
    event Unpaused();
    event EmergencyWithdrawal(address indexed admin, uint256 amount);

    constructor(address _payee, address _arbiter) {
        payer = msg.sender;
        payee = _payee;
        arbiter = _arbiter;
        admin = msg.sender;
    }

    function deposit() external payable notPaused {
        require(msg.sender == payer, "Only payer can deposit");
        deposits[payer] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function releaseFunds() external notPaused {
        require(msg.sender == arbiter, "Only arbiter can release funds");
        uint256 payment = deposits[payer];
        deposits[payer] = 0;
        payable(payee).transfer(payment);
        emit Released(payee, payment);
    }

    function refund() external notPaused {
        require(msg.sender == arbiter, "Only arbiter can refund");
        uint256 payment = deposits[payer];
        deposits[payer] = 0;
        payable(payer).transfer(payment);
        emit Refunded(payer, payment);
    }

    function pause() external onlyAdmin {
        isPaused = true;
        emit Paused();
    }

    function unpause() external onlyAdmin {
        isPaused = false;
        emit Unpaused();
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
        emit EmergencyWithdrawal(admin, balance);
    }
}