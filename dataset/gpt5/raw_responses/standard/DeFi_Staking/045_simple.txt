// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

abstract contract ReentrancyGuard {
    uint256 private _status;
    constructor() {
        _status = 1;
    }
    modifier nonReentrant() {
        require(_status != 2, "REENTRANCY");
        _status = 2;
        _;
        _status = 1;
    }
}

abstract contract Ownable {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    address public owner;

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_ADDRESS");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract BasicStaking is Ownable, ReentrancyGuard {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    // Staking balances
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    // Reward accounting
    uint256 public duration; // reward duration in seconds
    uint256 public periodFinish;
    uint256 public rewardRate; // rewards per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward, uint256 newRate, uint256 periodFinish);
    event RewardsDurationUpdated(uint256 newDuration);

    constructor(address _stakingToken, address _rewardToken, uint256 _duration) {
        require(_stakingToken != address(0) && _rewardToken != address(0), "ZERO_ADDRESS");
        require(_duration > 0, "BAD_DURATION");
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        duration = _duration;
    }

    // Views
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        uint256 timeDelta = lastTimeRewardApplicable() - lastUpdateTime;
        return rewardPerTokenStored + (timeDelta * rewardRate * 1e18) / _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        uint256 rptDelta = rewardPerToken() - userRewardPerTokenPaid[account];
        return (_balances[account] * rptDelta) / 1e18 + rewards[account];
    }

    // Core logic
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "ZERO_AMOUNT");
        _totalSupply += amount;
        _balances[msg.sender] += amount;
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "ZERO_AMOUNT");
        require(_balances[msg.sender] >= amount, "INSUFFICIENT_BALANCE");
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        require(stakingToken.transfer(msg.sender, amount), "TRANSFER_FAILED");
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardToken.transfer(msg.sender, reward), "REWARD_TRANSFER_FAILED");
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    // Admin: set reward duration (only when inactive)
    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(_duration > 0, "BAD_DURATION");
        require(block.timestamp > periodFinish, "ONGOING_PERIOD");
        duration = _duration;
        emit RewardsDurationUpdated(_duration);
    }

    // Admin: notify and fund new rewards
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        require(duration > 0, "BAD_DURATION");
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / duration;
        }
        require(rewardRate > 0, "ZERO_RATE");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;

        // Pull reward tokens from owner
        if (reward > 0) {
            require(rewardToken.transferFrom(msg.sender, address(this), reward), "FUND_TRANSFER_FAILED");
        }

        emit RewardAdded(reward, rewardRate, periodFinish);
    }

    // Admin: recover tokens mistakenly sent (cannot withdraw staked principal)
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(stakingToken), "CANNOT_RECOVER_STAKED");
        require(IERC20(token).transfer(owner, amount), "RECOVER_FAILED");
    }
}