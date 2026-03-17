// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DeFiStaking is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardRate; // rewards per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    uint256 public totalSupply;
    bool public emergencyMode;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event EmergencyWithdrawAll(address indexed to, uint256 stakingAmount, uint256 rewardAmount);
    event EmergencyModeEnabled();

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address stakingToken_, address rewardToken_) {
        require(stakingToken_ != address(0), "Invalid staking token");
        require(rewardToken_ != address(0), "Invalid reward token");
        stakingToken = IERC20(stakingToken_);
        rewardToken = IERC20(rewardToken_);
        lastUpdateTime = block.timestamp;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        // Halt reward accrual while paused
        if (paused()) {
            return lastUpdateTime;
        }
        return block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        uint256 timeDelta = lastTimeRewardApplicable() - lastUpdateTime;
        return rewardPerTokenStored + ((timeDelta * rewardRate * 1e18) / totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        uint256 paid = userRewardPerTokenPaid[account];
        uint256 duePerToken = rewardPerToken() - paid;
        return rewards[account] + ((balances[account] * duePerToken) / 1e18);
    }

    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(!emergencyMode, "Emergency mode");
        require(amount > 0, "Cannot stake 0");
        totalSupply += amount;
        balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant whenNotPaused updateReward(msg.sender) {
        require(!emergencyMode, "Emergency mode");
        require(amount > 0, "Cannot withdraw 0");
        uint256 bal = balances[msg.sender];
        require(bal >= amount, "Insufficient balance");
        balances[msg.sender] = bal - amount;
        totalSupply -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant whenNotPaused updateReward(msg.sender) {
        require(!emergencyMode, "Emergency mode");
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }

    // Admin functions

    function setRewardRate(uint256 newRate) external onlyOwner updateReward(address(0)) {
        uint256 old = rewardRate;
        rewardRate = newRate;
        lastUpdateTime = block.timestamp;
        emit RewardRateUpdated(old, newRate);
    }

    function pause() external onlyOwner {
        _pause();
        // reward accrual is halted via lastTimeRewardApplicable()
    }

    function unpause() external onlyOwner {
        require(!emergencyMode, "Cannot unpause in emergency");
        _unpause();
    }

    // Emergency: pause and withdraw all tokens (staking + rewards) to a safe address
    function emergencyPauseAndWithdrawAll(address to) external onlyOwner updateReward(address(0)) {
        require(to != address(0), "Invalid recipient");
        require(!emergencyMode, "Already in emergency");

        // Stop new rewards
        rewardRate = 0;

        // Pause operations
        _pause();
        emergencyMode = true;
        emit EmergencyModeEnabled();

        // Sweep all tokens
        uint256 stakingBal = stakingToken.balanceOf(address(this));
        uint256 rewardBal = rewardToken.balanceOf(address(this));

        if (stakingBal > 0) {
            stakingToken.safeTransfer(to, stakingBal);
        }
        if (rewardBal > 0) {
            rewardToken.safeTransfer(to, rewardBal);
        }

        emit EmergencyWithdrawAll(to, stakingBal, rewardBal);
    }

    // Rescue tokens mistakenly sent to this contract.
    // Non-core tokens can be rescued anytime; core tokens only when paused or emergency.
    function rescueTokens(address token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        IERC20 t = IERC20(token);

        if (token == address(stakingToken) || token == address(rewardToken)) {
            require(paused() || emergencyMode, "Core tokens: paused/emergency only");
        }

        t.safeTransfer(to, amount);
    }
}