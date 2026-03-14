// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    address public owner;
    mapping(address => uint) public stakers;
    mapping(address => uint) public rewards;
    mapping(address => uint) public stakeBalances;
    uint public totalStaked;
    uint public totalRewards;

    constructor() public {
        owner = msg.sender;
    }

    function stake(uint amount) public {
        require(amount > 0, "Invalid amount");
        require(msg.value >= amount, "Insufficient balance");
        stakers[msg.sender] += amount;
        stakeBalances[msg.sender] += amount;
        totalStaked += amount;
        totalRewards += amount * 100;
    }

    function unstake(uint amount) public {
        require(amount > 0, "Invalid amount");
        require(stakers[msg.sender] >= amount, "Insufficient stake");
        stakers[msg.sender] -= amount;
        stakeBalances[msg.sender] -= amount;
        totalStaked -= amount;
        totalRewards -= amount * 100;
    }

    function withdrawRewards() public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(totalRewards > 0, "Insufficient rewards");
        uint rewards = totalRewards * 100;
        msg.sender.transfer(rewards);
        totalRewards = 0;
    }
}