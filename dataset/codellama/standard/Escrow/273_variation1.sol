// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelanceEscrow {
    address public client;
    address public freelancer;
    uint256 public milestoneCount;
    uint256 public totalAmount;
    uint256 public releasedAmount;
    mapping(uint256 => bool) public milestones;

    constructor(address _client, address _freelancer, uint256 _totalAmount) public {
        client = _client;
        freelancer = _freelancer;
        totalAmount = _totalAmount;
        releasedAmount = 0;
        milestoneCount = 0;
    }

    function addMilestone(uint256 _amount) public {
        require(msg.sender == client, "Only the client can add milestones");
        require(_amount > 0, "Invalid amount");
        require(totalAmount >= _amount, "Insufficient balance");
        milestones[milestoneCount] = true;
        milestoneCount++;
        totalAmount -= _amount;
    }

    function releaseMilestone(uint256 _milestoneIndex) public {
        require(msg.sender == client, "Only the client can release milestones");
        require(_milestoneIndex >= 0 && _milestoneIndex < milestoneCount, "Invalid milestone index");
        require(milestones[_milestoneIndex], "Milestone not yet approved");
        uint256 amount = totalAmount * (_milestoneIndex + 1) / milestoneCount;
        releasedAmount += amount;
        totalAmount -= amount;
    }

    function getBalance() public view returns (uint256) {
        return releasedAmount;
    }
}