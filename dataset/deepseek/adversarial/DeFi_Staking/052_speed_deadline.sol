// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint2atural amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Staking {
    IERC20 public token;
    uint256 public stakingPeriod = 30 days;
    uint256 public rewardRate = 10; // 10% per year

    struct Stake {
        uint256 amount;
        uint256 startTime;
        bool claimed;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        token.transferFrom(msg.sender, address(this), amount);
        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender] = Stake({amount: amount, startTime: block.timestamp, claimed: false});
        } else {
            stakes[msg.sender].amount += amount;
        }
        emit Staked(msg.sender, amount);
    }

    function unstake() external {
        require(stakes[msg.sender].amount > 0, "No staked tokens");
        uint256 amount = stakes[msg.sender].amount;
        uint256 reward = calculateReward(msg.sender);
        token.transfer(msg.sender, amount + reward);
        delete stakes[msg.sender];
        emit Unstaked(msg.sender, amount);
    }

    function calculateReward(address user) public view returns (uint256) {
        Stake memory stake = stakes[user];
        if (stake.amount == 0) return 0;
        uint256 timeDiff = block.timestamp - stake.startTime;
        if (timeDiff > stakingPeriod) timeDiff = stakingPeriod;
        uint256 reward = (stake.amount * rewardRate * timeDiff) / (365 days * 100);
        return reward;
    }

    function claimReward() external {
        require(stakes[msg.sender].amount > 0, "No staked tokens");
        require(!stakes[msg.sender].claimed, "Reward already claimed");
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No reward to claim");
        stakes[msg.sender].claimed = true;
        token.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }
}