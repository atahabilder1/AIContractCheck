// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Staking Contract with Lockup Periods
contract LockupStaking {
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    address public owner;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    struct StakeInfo {
        uint256 amount;
        uint256 lockEndTime;
        uint256 lockDuration;
        uint256 rewardDebt;
    }

    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    uint256 public totalStaked;

    uint256 public constant MIN_LOCK = 7 days;
    uint256 public constant MAX_LOCK = 365 days;
    uint256 public constant LOCK_BONUS_MULTIPLIER = 200; // 2x max bonus

    event Staked(address indexed user, uint256 amount, uint256 lockDuration);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
        owner = msg.sender;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18 / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        StakeInfo storage stake = stakes[account];
        uint256 bonus = getLockBonus(stake.lockDuration);
        return (stake.amount * (rewardPerToken() - userRewardPerTokenPaid[account]) * bonus / 100 / 1e18) + rewards[account];
    }

    function getLockBonus(uint256 lockDuration) public pure returns (uint256) {
        if (lockDuration < MIN_LOCK) return 100;
        if (lockDuration >= MAX_LOCK) return LOCK_BONUS_MULTIPLIER;
        return 100 + ((lockDuration - MIN_LOCK) * (LOCK_BONUS_MULTIPLIER - 100) / (MAX_LOCK - MIN_LOCK));
    }

    function stake(uint256 amount, uint256 lockDuration) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(lockDuration >= MIN_LOCK && lockDuration <= MAX_LOCK, "Invalid lock duration");
        require(stakes[msg.sender].amount == 0, "Already staking");

        stakes[msg.sender] = StakeInfo({
            amount: amount,
            lockEndTime: block.timestamp + lockDuration,
            lockDuration: lockDuration,
            rewardDebt: 0
        });

        totalStaked += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, lockDuration);
    }

    function withdraw() external updateReward(msg.sender) {
        StakeInfo storage stake = stakes[msg.sender];
        require(stake.amount > 0, "No stake");
        require(block.timestamp >= stake.lockEndTime, "Still locked");

        uint256 amount = stake.amount;
        totalStaked -= amount;
        delete stakes[msg.sender];

        stakingToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
