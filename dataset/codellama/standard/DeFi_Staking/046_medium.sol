// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingPool {
    address public owner;
    uint256 public totalStaked;
    uint256 public totalRewards;
    uint256 public lastRewardBlock;
    uint256 public tier1Lockup;
    uint256 public tier2Lockup;
    uint256 public tier3Lockup;
    uint256 public earlyWithdrawalPenalty;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewardsBalances;

    constructor(uint256 _tier1Lockup, uint256 _tier2Lockup, uint256 _tier3Lockup, uint256 _earlyWithdrawalPenalty) {
        owner = msg.sender;
        totalStaked = 0;
        totalRewards = 0;
        lastRewardBlock = block.number;
        tier1Lockup = _tier1Lockup;
        tier2Lockup = _tier2Lockup;
        tier3Lockup = _tier3Lockup;
        earlyWithdrawalPenalty = _earlyWithdrawalPenalty;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Invalid amount");
        require(amount <= msg.sender.balance, "Insufficient balance");

        totalStaked += amount;
        stakedBalances[msg.sender] += amount;

        if (block.number >= lastRewardBlock + tier1Lockup) {
            rewardsBalances[msg.sender] += amount * 100;
        } else if (block.number >= lastRewardBlock + tier2Lockup) {
            rewardsBalances[msg.sender] += amount * 50;
        } else if (block.number >= lastRewardBlock + tier3Lockup) {
            rewardsBalances[msg.sender] += amount * 25;
        }

        lastRewardBlock = block.number;
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "Invalid amount");
        require(amount <= stakedBalances[msg.sender], "Insufficient balance");

        uint256 penalty = 0;
        if (block.number < lastRewardBlock + tier1Lockup) {
            penalty = amount * earlyWithdrawalPenalty;
        }

        totalStaked -= amount;
        stakedBalances[msg.sender] -= amount;
        rewardsBalances[msg.sender] -= amount;

        msg.sender.transfer(amount - penalty);
    }

    function getRewards() public view returns (uint256) {
        return rewardsBalances[msg.sender];
    }

    function getStakedBalance() public view returns (uint256) {
        return stakedBalances[msg.sender];
    }
}