// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public admin;
    bool public paused;
    
    event Deposit(address indexed user, uint256 amount, uint256 targetChainId);
    event Withdraw(address indexed user, uint256 amount);
    event Paused();
    event Unpaused();
    event EmergencyWithdrawal(address indexed admin, uint256 amount);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Operations are paused");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        paused = false;
    }
    
    function deposit(uint256 targetChainId) external payable whenNotPaused {
        require(msg.value > 0, "Must send Ether");
        emit Deposit(msg.sender, msg.value, targetChainId);
    }
    
    function withdraw(uint256 amount) external whenNotPaused {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }
    
    function pause() external onlyAdmin {
        paused = true;
        emit Paused();
    }
    
    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused();
    }
    
    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(admin).transfer(balance);
        emit EmergencyWithdrawal(admin, balance);
    }
    
    receive() external payable {}
}