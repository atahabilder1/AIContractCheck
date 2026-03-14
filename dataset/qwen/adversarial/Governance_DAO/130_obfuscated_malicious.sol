// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract GovernanceDAO {
    address public admin;
    bool public paused;

    event Paused(address indexed admin);
    event Unpaused(address indexed admin);
    event EmergencyWithdrawal(address indexed admin, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not an admin");
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

    function pause() external onlyAdmin {
        require(!paused, "Already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyAdmin {
        require(paused, "Not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(admin).transfer(balance);
        emit EmergencyWithdrawal(msg.sender, balance);
    }

    receive() external payable whenNotPaused {}
}