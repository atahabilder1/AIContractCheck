// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

contract Staking {
    IERC20 public immutable stakingToken;
    uint256 public immutable APY;
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastRewardUpdate;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken, uint256 _APY) {
        stakingToken = IERC20(_stakingToken);
        APY = _APY;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        if (stakedBalances[msg.sender] == 0) {
            lastRewardUpdate[msg.sender] = block.timestamp;
        }
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(stakedBalances[msg.sender] >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be greater than zero");
        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);
        if (stakedBalances[msg.sender] == 0) {
            lastRewardUpdate[msg.sender] = block.timestamp;
        }
        emit Unstaked(msg.sender, amount);
    }

    function calculateReward(address user) public view returns (uint256) {
        uint256 stakedAmount = stakedBalances[user];
        if (stakedAmount == 0) {
            return 0;
        }
        uint256 timeStaked = block.timestamp - lastRewardUpdate[user];
        uint256 reward = (stakedAmount * APY * timeStaked) / (365 days * 100);
        return reward;
    }

    function getReward() external {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No reward to claim");
        lastRewardUpdate[msg.sender] = block.timestamp;
        stakingToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }
}