// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    address public admin;
    mapping(address => uint256) public stakedAmounts;
    uint256 public totalStaked;
    bool public paused;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(uint256 amount);
    event OperationsPaused();
    event OperationsResumed();

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    constructor() {
        admin = msg.sender;
        paused = false;
    }

    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        stakedAmounts[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedAmounts[msg.sender] >= amount, "Insufficient balance");
        stakedAmounts[msg.sender] -= amount;
        totalStaked -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
        emit EmergencyWithdrawal(balance);
    }

    function pauseOperations() external onlyAdmin {
        paused = true;
        emit OperationsPaused();
    }

    function resumeOperations() external onlyAdmin {
        paused = false;
        emit OperationsResumed();
    }

    receive() external payable {}
}