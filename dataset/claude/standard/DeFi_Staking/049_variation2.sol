// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DynamicAPYStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    uint256 public baseAPY = 20e16; // 20%
    uint256 public minAPY = 5e16;   // 5%
    uint256 public maxAPY = 50e16;  // 50%

    uint256 public tvlThresholdLow = 100_000e18;
    uint256 public tvlThresholdHigh = 1_000_000e18;

    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    uint256 public lastUpdateTime;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    mapping(address => UserInfo) public userInfo;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event APYParametersUpdated(uint256 baseAPY, uint256 minAPY, uint256 maxAPY);
    event TVLThresholdsUpdated(uint256 low, uint256 high);

    constructor(
        address _stakingToken,
        address _rewardToken
    ) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastUpdateTime = block.timestamp;
    }

    function currentAPY() public view returns (uint256) {
        if (totalStaked == 0) return maxAPY;

        if (totalStaked <= tvlThresholdLow) {
            return maxAPY;
        } else if (totalStaked >= tvlThresholdHigh) {
            return minAPY;
        } else {
            uint256 range = tvlThresholdHigh - tvlThresholdLow;
            uint256 excess = totalStaked - tvlThresholdLow;
            uint256 apyRange = maxAPY - minAPY;
            return maxAPY - (apyRange * excess / range);
        }
    }

    function _updatePool() internal {
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastUpdateTime;
        if (elapsed == 0) return;

        uint256 apy = currentAPY();
        uint256 reward = totalStaked * apy * elapsed / (SECONDS_PER_YEAR * PRECISION);

        accRewardPerShare += reward * PRECISION / totalStaked;
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0");

        _updatePool();

        UserInfo storage user = userInfo[msg.sender];

        if (user.amount > 0) {
            uint256 pending = user.amount * accRewardPerShare / PRECISION - user.rewardDebt;
            user.pendingRewards += pending;
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        user.amount += _amount;
        totalStaked += _amount;
        user.rewardDebt = user.amount * accRewardPerShare / PRECISION;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient staked balance");
        require(_amount > 0, "Cannot withdraw 0");

        _updatePool();

        uint256 pending = user.amount * accRewardPerShare / PRECISION - user.rewardDebt;
        user.pendingRewards += pending;

        user.amount -= _amount;
        totalStaked -= _amount;
        user.rewardDebt = user.amount * accRewardPerShare / PRECISION;

        stakingToken.safeTransfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    function claimRewards() external nonReentrant {
        _updatePool();

        UserInfo storage user = userInfo[msg.sender];

        uint256 pending = user.amount * accRewardPerShare / PRECISION - user.rewardDebt;
        uint256 totalRewards = user.pendingRewards + pending;
        require(totalRewards > 0, "No rewards to claim");

        user.pendingRewards = 0;
        user.rewardDebt = user.amount * accRewardPerShare / PRECISION;

        rewardToken.safeTransfer(msg.sender, totalRewards);

        emit RewardsClaimed(msg.sender, totalRewards);
    }

    function pendingRewards(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accRewardPerShare = accRewardPerShare;

        if (totalStaked > 0 && block.timestamp > lastUpdateTime) {
            uint256 elapsed = block.timestamp - lastUpdateTime;
            uint256 apy = currentAPY();
            uint256 reward = totalStaked * apy * elapsed / (SECONDS_PER_YEAR * PRECISION);
            _accRewardPerShare += reward * PRECISION / totalStaked;
        }

        uint256 pending = user.amount * _accRewardPerShare / PRECISION - user.rewardDebt;
        return user.pendingRewards + pending;
    }

    function setAPYParameters(
        uint256 _baseAPY,
        uint256 _minAPY,
        uint256 _maxAPY
    ) external onlyOwner {
        require(_minAPY <= _baseAPY && _baseAPY <= _maxAPY, "Invalid APY range");
        _updatePool();
        baseAPY = _baseAPY;
        minAPY = _minAPY;
        maxAPY = _maxAPY;
        emit APYParametersUpdated(_baseAPY, _minAPY, _maxAPY);
    }

    function setTVLThresholds(uint256 _low, uint256 _high) external onlyOwner {
        require(_low < _high, "Low must be less than high");
        _updatePool();
        tvlThresholdLow = _low;
        tvlThresholdHigh = _high;
        emit TVLThresholdsUpdated(_low, _high);
    }

    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        require(amount > 0, "Nothing to withdraw");

        totalStaked -= amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.pendingRewards = 0;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function depositRewards(uint256 _amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
    }
}