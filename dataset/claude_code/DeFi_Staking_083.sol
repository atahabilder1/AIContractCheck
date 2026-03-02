// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Production-ready staking with tiered rewards
contract ProductionStaking {
    address public owner;
    address public stakingToken;
    address public rewardToken;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    bool public paused;
    uint256 public minStake;
    uint256 public lockDuration;

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lockEnd;
        uint8 tier;
    }

    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;
    mapping(uint8 => uint256) public tierMultipliers; // basis points

    event Staked(address indexed user, uint256 amount, uint8 tier);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event TierUpdated(address indexed user, uint8 newTier);

    modifier onlyOwner() { require(msg.sender == owner); _; }
    modifier whenNotPaused() { require(!paused); _; }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            stakes[account].rewardDebt = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate, uint256 _minStake, uint256 _lockDuration) {
        owner = msg.sender;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
        minStake = _minStake;
        lockDuration = _lockDuration;
        // Set tier multipliers (basis points: 10000 = 1x)
        tierMultipliers[1] = 10000;  // 1x
        tierMultipliers[2] = 12500;  // 1.25x
        tierMultipliers[3] = 15000;  // 1.5x
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18 / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        StakeInfo memory info = stakes[account];
        uint256 multiplier = tierMultipliers[info.tier] > 0 ? tierMultipliers[info.tier] : 10000;
        uint256 baseReward = (info.amount * (rewardPerToken() - info.rewardDebt) / 1e18);
        return (baseReward * multiplier / 10000) + rewards[account];
    }

    function getTier(uint256 amount) public pure returns (uint8) {
        if (amount >= 100000e18) return 3;
        if (amount >= 10000e18) return 2;
        return 1;
    }

    function stake(uint256 amount) external whenNotPaused updateReward(msg.sender) {
        require(amount >= minStake, "Below minimum stake");
        totalStaked += amount;
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].lockEnd = block.timestamp + lockDuration;
        stakes[msg.sender].tier = getTier(stakes[msg.sender].amount);
        IERC20(stakingToken).transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount, stakes[msg.sender].tier);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        StakeInfo storage info = stakes[msg.sender];
        require(block.timestamp >= info.lockEnd, "Still locked");
        require(info.amount >= amount, "Insufficient balance");
        totalStaked -= amount;
        info.amount -= amount;
        info.tier = getTier(info.amount);
        IERC20(stakingToken).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IERC20(rewardToken).transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function emergencyWithdraw() external {
        StakeInfo storage info = stakes[msg.sender];
        uint256 amount = info.amount;
        totalStaked -= amount;
        info.amount = 0;
        info.tier = 0;
        rewards[msg.sender] = 0;
        IERC20(stakingToken).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // Admin
    function setRewardRate(uint256 rate) external onlyOwner updateReward(address(0)) { rewardRate = rate; }
    function setMinStake(uint256 min) external onlyOwner { minStake = min; }
    function setLockDuration(uint256 duration) external onlyOwner { lockDuration = duration; }
    function setTierMultiplier(uint8 tier, uint256 multiplier) external onlyOwner { tierMultipliers[tier] = multiplier; }
    function pause() external onlyOwner { paused = true; }
    function unpause() external onlyOwner { paused = false; }
    function recoverTokens(address token, uint256 amount) external onlyOwner {
        require(token != stakingToken, "Cannot recover staking token");
        IERC20(token).transfer(owner, amount);
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
