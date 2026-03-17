// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);
}

contract TestnetStaking {
    // Basic Ownable
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Simple reentrancy guard
    uint256 private _unlocked = 1;
    modifier nonReentrant() {
        require(_unlocked == 1, "Reentrant");
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    // Tokens
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    // Staking accounting
    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    // Rewards accounting (Synthetix-style)
    uint256 public rewardRate; // reward tokens per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // Pausable
    bool public paused;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event PausedSet(bool paused);
    event RewardsFunded(address indexed funder, uint256 amount);

    constructor(address _stakingToken, address _rewardToken, uint256 _initialRewardRate) {
        require(_stakingToken != address(0) && _rewardToken != address(0), "Zero address");
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);

        rewardRate = _initialRewardRate;
        lastUpdateTime = block.timestamp;
    }

    // Ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Views
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        uint256 timeDelta = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + (timeDelta * rewardRate * 1e18) / totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        uint256 rpt = rewardPerToken();
        return ((balances[account] * (rpt - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    function getUserInfo(address account) external view returns (uint256 staked, uint256 pendingReward) {
        staked = balances[account];
        pendingReward = earned(account);
    }

    // Internal reward update
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // User actions
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(!paused, "Paused");
        require(amount > 0, "Zero amount");

        totalSupply += amount;
        balances[msg.sender] += amount;

        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Stake transfer failed");
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Zero amount");
        require(balances[msg.sender] >= amount, "Insufficient staked");

        balances[msg.sender] -= amount;
        totalSupply -= amount;

        require(stakingToken.transfer(msg.sender, amount), "Withdraw transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardToken.transfer(msg.sender, reward), "Reward transfer failed");
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }

    // Admin actions
    function setRewardRate(uint256 newRate) external onlyOwner updateReward(address(0)) {
        uint256 old = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(old, newRate);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedSet(_paused);
    }

    // Fund rewards by transferring reward tokens to the contract
    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Fund transfer failed");
        emit RewardsFunded(msg.sender, amount);
    }

    // Rescue tokens (for testnet convenience). Avoid rescuing staking tokens if there is liquidity.
    function rescueTokens(address token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Zero to");
        if (token == address(stakingToken)) {
            require(totalSupply == 0, "Active stakes exist");
        }
        require(IERC20(token).transfer(to, amount), "Rescue failed");
    }
}