// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CrossChainBridge {
    address public admin;
    bool public paused;

    event EmergencyWithdrawal(address indexed admin, uint256 amount);
    event OperationPaused(address indexed admin);
    event OperationResumed(address indexed admin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Operation paused");
        _;
    }

    constructor() {
        admin = msg.sender;
        paused = false;
    }

    function deposit() external payable whenNotPaused {}

    function withdraw(uint256 _amount) external whenNotPaused {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(msg.sender).transfer(_amount);
    }

    function emergencyWithdrawal() external onlyAdmin {
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
        emit EmergencyWithdrawal(admin, balance);
    }

    function pauseOperations() external onlyAdmin {
        paused = true;
        emit OperationPaused(admin);
    }

    function resumeOperations() external onlyAdmin {
        paused = false;
        emit OperationResumed(admin);
    }

    receive() external payable {}
}