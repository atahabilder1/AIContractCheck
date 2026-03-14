// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public admin;
    bool public paused;

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount);
    event EmergencyWithdrawal(address indexed admin, uint256 amount);
    event Paused(address indexed admin);
    event Unpaused(address indexed admin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not the admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
        paused = false;
    }

    function deposit() external payable whenNotPaused {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external whenNotPaused {
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(address(this).balance >= _amount, "Insufficient funds");
        payable(msg.sender).transfer(_amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
        emit EmergencyWithdrawal(admin, balance);
    }

    function pause() external onlyAdmin {
        paused = true;
        emit Paused(admin);
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused(admin);
    }
}