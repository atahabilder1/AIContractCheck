// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    uint256 public rewardRate;
    uint256 public totalStaked;

    struct Stake {
        uint256 amount;
        uint256 since;
        uint256 claimable;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(IERC20 _stakingToken, IERC20 _rewardToken, uint256 _rewardRate) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        if (stakes[msg.sender].amount > 0) {
            stakes[msg.sender].claimable += _calculateRewards(msg.sender);
        }
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].since = block.timestamp;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(stakes[msg.sender].amount >= amount, "Insufficient balance");
        claimRewards();
        stakes[msg.sender].amount -= amount;
        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].since = 0;
        }
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() public {
        uint256 rewards = stakes[msg.sender].claimable + _calculateRewards(msg.sender);
        if (rewards > 0) {
            stakes[msg.sender].claimable = 0;
            stakes[msg.sender].since = block.timestamp;
            rewardToken.transfer(msg.sender, rewards);
            emit RewardClaimed(msg.sender, rewards);
        }
    }

    function _calculateRewards(address user) internal view returns (uint256) {
        if (stakes[user].amount == 0) {
            return 0;
        }
        uint256 timeElapsed = block.timestamp - stakes[user].since;
        return (stakes[user].amount * timeElapsed * rewardRate) / 1e18;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}