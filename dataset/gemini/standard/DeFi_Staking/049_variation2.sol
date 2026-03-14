// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingContract is Ownable {
    using SafeMath for uint256;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public constant BASE_REWARD_RATE_PER_SECOND = 1e12; // Example: 1e12 reward tokens per second for 1 total staked token
    uint256 public constant MAX_APY_PERCENT = 100; // Maximum APY in percent
    uint256 public constant REWARD_TOKEN_DECIMALS = 18; // Assuming reward token has 18 decimals
    uint256 public constant SCALING_FACTOR = 10**REWARD_TOKEN_DECIMALS;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userInfo;
    uint256 public totalStakedAmount;

    uint256 public lastRewardBlock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, "Deposit amount must be greater than 0");

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        UserInfo storage user = userInfo[msg.sender];
        uint256 pendingReward = _pendingReward(msg.sender);

        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.rewardDebt.add(pendingReward);

        totalStakedAmount = totalStakedAmount.add(_amount);

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Withdraw amount must be greater than 0");

        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient staked amount");

        uint256 pendingReward = _pendingReward(msg.sender);

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.rewardDebt.add(pendingReward);

        totalStakedAmount = totalStakedAmount.sub(_amount);

        stakingToken.transfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function harvest() public {
        uint256 reward = _pendingReward(msg.sender);
        require(reward > 0, "No reward to harvest");

        UserInfo storage user = userInfo[msg.sender];
        user.rewardDebt = user.rewardDebt.add(reward); // Mark reward as paid

        rewardToken.transfer(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    function _pendingReward(address _user) internal view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        if (user.amount == 0) {
            return 0;
        }

        uint256 currentRewardRate = _getCurrentRewardRate();
        uint256 timeElapsed = block.timestamp.sub(lastRewardBlock);
        uint256 calculatedReward = currentRewardRate.mul(timeElapsed).div(SCALING_FACTOR);

        return calculatedReward.sub(user.rewardDebt);
    }

    function _getCurrentRewardRate() internal view returns (uint256) {
        // This function dynamically adjusts the reward rate based on total staked amount
        // to maintain a target APY within limits.
        // The formula here is a simplified example. A more robust implementation might use
        // logarithmic or exponential scaling, or a lookup table.

        // For simplicity, let's assume a target APY and scale the reward rate.
        // APY = (Reward Rate per second * Seconds in a year * 100) / Total Staked Amount
        // Reward Rate per second = (APY * Total Staked Amount) / (Seconds in a year * 100)

        uint256 secondsInAYear = 365 days * 24 hours * 60 minutes * 60 seconds; // Approx. 31,536,000 seconds

        // Calculate a target reward rate that would result in MAX_APY_PERCENT if totalStakedAmount was very low.
        // This is a conceptual starting point.
        uint256 maxPossibleRewardRate = BASE_REWARD_RATE_PER_SECOND;

        // If totalStakedAmount is 0, we can't divide by it. Return a base rate or a rate that makes sense.
        if (totalStakedAmount == 0) {
            // Return a rate that would yield a significant APY if someone stakes.
            // This might need careful tuning.
            return maxPossibleRewardRate;
        }

        // Calculate the effective APY based on the current total staked amount.
        // This calculation is to *inform* the reward rate, not directly set it.
        // The goal is to make the reward rate such that if totalStakedAmount *remained constant*,
        // the APY would be what we want.

        // Let's define a "sweet spot" for total staked amount where APY is highest.
        // For simplicity, let's say the highest APY is achieved when totalStakedAmount is 1e18 (1 staked token with 18 decimals).
        uint256 sweetSpotAmount = 1e18 * (10**stakingToken.decimals()); // Adjust for staking token decimals

        // Calculate a factor based on how far totalStakedAmount is from the sweet spot.
        // If totalStakedAmount is less than sweetSpotAmount, we want a higher reward rate.
        // If totalStakedAmount is more than sweetSpotAmount, we want a lower reward rate.
        uint256 scalingFactor = 0;
        if (totalStakedAmount < sweetSpotAmount) {
            // Linear scaling example: higher rate when staked amount is lower
            scalingFactor = sweetSpotAmount.div(totalStakedAmount);
        } else {
            // If staked amount is higher than sweet spot, we want to cap the reward rate.
            // For this example, we'll cap it to a rate that would yield MAX_APY_PERCENT with the sweet spot amount.
            scalingFactor = 1; // This means we are at or above the sweet spot, use the base rate calculation logic below.
        }

        // Limit the scaling factor to avoid excessively high or low rates.
        // For instance, cap scalingFactor at 10x or 100x.
        scalingFactor = scalingFactor > 100 ? 100 : scalingFactor; // Cap scaling

        // Calculate the adjusted reward rate.
        // This is a simplified model. A real-world scenario would involve more complex calculations
        // to precisely target an APY curve.
        uint256 adjustedRewardRate = maxPossibleRewardRate.mul(scalingFactor);

        // Ensure the adjusted reward rate doesn't exceed a maximum possible rate that would be sustainable.
        // This maximum rate could be derived from MAX_APY_PERCENT.
        // For example, the rate that provides MAX_APY_PERCENT on the sweetSpotAmount.
        uint256 maxSustainableRate = (MAX_APY_PERCENT * sweetSpotAmount) / secondsInAYear;
        maxSustainableRate = maxSustainableRate.mul(SCALING_FACTOR).div(100); // Adjust for SCALING_FACTOR and APY percentage

        if (adjustedRewardRate > maxSustainableRate) {
            adjustedRewardRate = maxSustainableRate;
        }

        // Ensure reward rate is not zero if there's any staking activity.
        if (totalStakedAmount > 0 && adjustedRewardRate == 0) {
             adjustedRewardRate = 1; // Smallest possible rate
        }

        return adjustedRewardRate;
    }

    function _updateReward() internal {
        uint256 currentRewardRate = _getCurrentRewardRate();
        uint256 timeElapsed = block.timestamp.sub(lastRewardBlock);
        uint256 rewards = currentRewardRate.mul(timeElapsed).div(SCALING_FACTOR);

        // This function is intended to be called by deposit/withdraw/harvest to update state.
        // In a more complex system, a time-based mechanism might trigger this.
        // For this simple example, we'll update lastRewardBlock here.
        lastRewardBlock = block.timestamp;
    }

    function pendingReward(address _user) public view returns (uint256) {
        return _pendingReward(_user);
    }

    function getStakingToken() public view returns (address) {
        return address(stakingToken);
    }

    function getRewardToken() public view returns (address) {
        return address(rewardToken);
    }

    function getUserInfo(address _user) public view returns (uint256, uint256) {
        UserInfo storage user = userInfo[_user];
        return (user.amount, user.rewardDebt);
    }

    function getTotalStakedAmount() public view returns (uint256) {
        return totalStakedAmount;
    }

    // --- Admin functions ---

    function setStakingToken(address _stakingToken) public onlyOwner {
        stakingToken = IERC20(_stakingToken);
    }

    function setRewardToken(address _rewardToken) public onlyOwner {
        rewardToken = IERC20(_rewardToken);
    }

    function setBaseRewardRatePerSecond(uint256 _rate) public onlyOwner {
        // BASE_REWARD_RATE_PER_SECOND = _rate; // This is a constant, cannot be changed directly.
        // To change this, the contract needs to be re-deployed or refactored to make it a variable.
        // For this example, we'll assume it's a parameter that can be adjusted via a setter if it were a variable.
        // For now, it's a constant and cannot be changed after deployment.
    }

    function setMaxApyPercent(uint256 _apy) public onlyOwner {
        // MAX_APY_PERCENT = _apy; // This is a constant, cannot be changed directly.
        // Similar to BASE_REWARD_RATE_PER_SECOND, this would need refactoring to be a variable.
    }
}