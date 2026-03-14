// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    address public owner;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public rewards;

    constructor() public {
        owner = msg.sender;
    }

    function stake(uint256 amount) public {
        require(msg.value >= amount, "Insufficient balance");
        stakes[msg.sender] += amount;
    }

    function withdraw(uint256 amount) public {
        require(stakes[msg.sender] >= amount, "Insufficient stake");
        stakes[msg.sender] -= amount;
        msg.sender.transfer(amount);
    }

    function getReward() public {
        require(rewards[msg.sender] > 0, "No rewards available");
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        msg.sender.transfer(reward);
    }
}