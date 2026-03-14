// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Staking {
    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastStakeTime;
    }

    mapping(address => Stake) public stakes;
    uint256 public totalStaked;
    uint256 public rewardPerSecond;
    uint256 public startTime;
    uint256 public rewardSupply;

    constructor(uint256 _rewardPerSecond, uint256 _rewardSupply) {
        require(_rewardPerSecond > 0, "Reward rate must be greater than zero");
        require(_rewardSupply > 0, "Reward supply must be greater than zero");
        rewardPerSecond = _rewardPerSecond;
        rewardSupply = _rewardSupply;
        startTime = block.timestamp;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        if (stakes[msg.sender].amount > 0) {
            updateReward(msg.sender);
        }
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].lastStakeTime = block.timestamp;
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * rewardPerSecond * (block.timestamp - startTime)) / rewardSupply;
        totalStaked += amount;
    }

    function unstake(uint256 amount) public {
        require(stakes[msg.sender].amount >= amount, "Insufficient balance");
        if (stakes[msg.sender].amount > 0) {
            updateReward(msg.sender);
        }
        stakes[msg.sender].amount -= amount;
        stakes[msg.sender].lastStakeTime = block.timestamp;
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * rewardPerSecond * (block.timestamp - startTime)) / rewardSupply;
        totalStaked -= amount;
    }

    function updateReward(address user) internal {
        uint256 timeElapsed = block.timestamp - stakes[user].lastStakeTime;
        uint256 reward = (stakes[user].amount * rewardPerSecond * timeElapsed) / rewardSupply;
        stakes[user].rewardDebt += reward;
    }

    function claimReward() public {
        updateReward(msg.sender);
        uint256 reward = stakes[msg.sender].rewardDebt;
        stakes[msg.sender].rewardDebt = 0;
        require(rewardSupply >= reward, "Insufficient reward supply");
        rewardSupply -= reward;
    }

    function getReward() public view returns (uint256) {
        if (stakes[msg.sender].amount == 0) {
            return 0;
        }
        uint256 timeElapsed = block.timestamp - stakes[msg.sender].lastStakeTime;
        uint256 reward = (stakes[msg.sender].amount * rewardPerSecond * timeElapsed) / rewardSupply;
        return reward + stakes[msg.sender].rewardDebt;
    }
}