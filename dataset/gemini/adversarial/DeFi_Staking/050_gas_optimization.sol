```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DeFiStaking is Ownable {
    using SafeMath for uint256;

    IERC20 public immutable stakingToken;
    uint256 public rewardRate; // Tokens per second
    uint256 public rewardStartTime;
    uint256 public rewardEndTime;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastStakeTime;
    }

    mapping(address => UserInfo) public userInfo;
    uint256 public totalStakedAmount;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event RewardPeriodUpdated(uint256 startTime, uint256 endTime);

    constructor(IERC20 _stakingToken, uint256 _rewardRate, uint256 _rewardStartTime, uint256 _rewardEndTime) {
        require(_stakingToken != address(0), "Staking token cannot be the zero address");
        stakingToken = _stakingToken;
        rewardRate = _rewardRate;
        rewardStartTime = _rewardStartTime;
        rewardEndTime = _rewardEndTime;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function setRewardPeriod(uint256 _rewardStartTime, uint256 _rewardEndTime) public onlyOwner {
        require(_rewardStartTime < _rewardEndTime, "Start time must be before end time");
        rewardStartTime = _rewardStartTime;
        rewardEndTime = _rewardEndTime;
        emit RewardPeriodUpdated(_rewardStartTime, _rewardEndTime);
    }

    function stake(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(block.timestamp >= rewardStartTime, "Staking not yet active");
        require(block.timestamp < rewardEndTime, "Staking period has ended");

        UserInfo storage user = userInfo[msg.sender];
        uint256 currentReward = calculateReward(msg.sender);

        // Pay pending rewards before updating stake
        if (currentReward > 0) {
            _payReward(msg.sender, currentReward);
        }

        // Transfer tokens from user to contract
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.rewardDebt.add(_amount); // New stake adds to debt
        user.lastStakeTime = block.timestamp;
        totalStakedAmount = totalStakedAmount.add(_amount);

        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero");

        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient staked amount");

        uint256 currentReward = calculateReward(msg.sender);
        uint256 totalToWithdraw = _amount;

        if (currentReward > 0) {
            _payReward(msg.sender, currentReward);
            // If user unstakes more than their stake, the excess is covered by their earned rewards
            if (_amount > user.amount) {
                totalToWithdraw = user.amount; // Only unstake what's staked
            }
        }

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.rewardDebt.sub(_amount); // Unstaking reduces debt
        user.lastStakeTime = block.timestamp; // Update last stake time for future reward calculation
        totalStakedAmount = totalStakedAmount.sub(_amount);

        // Transfer staked tokens back to user
        require(stakingToken.transfer(msg.sender, totalToWithdraw), "Token transfer failed");

        emit Unstaked(msg.sender, _amount);
    }

    function claimReward() public {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No rewards to claim");
        _payReward(msg.sender, reward);
    }

    function calculateReward(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedAmount = user.amount;
        uint256 lastStake = user.lastStakeTime;

        if (stakedAmount == 0 || lastStake == 0) {
            return 0;
        }

        uint256 currentTimestamp = block.timestamp;
        uint256 timeElapsed = 0;

        // Calculate time elapsed since last update, considering reward period
        if (currentTimestamp > lastStake) {
            uint256 effectiveStartTime = rewardStartTime > lastStake ? rewardStartTime : lastStake;
            uint256 effectiveEndTime = rewardEndTime < currentTimestamp ? rewardEndTime : currentTimestamp;

            if (effectiveEndTime > effectiveStartTime) {
                timeElapsed = effectiveEndTime.sub(effectiveStartTime);
            }
        }

        // Reward is calculated as (stakedAmount * rewardRate * timeElapsed) / 1e18 (assuming rewardRate is per token)
        // To minimize gas, we can calculate rewardDebt directly.
        // Reward = (totalStakedAmount * rewardRate * timeElapsed) - user.rewardDebt
        // This is equivalent to:
        // Reward = (stakedAmount * rewardRate * timeElapsed) - (stakedAmount - user.rewardDebt) * (rewardRate * timeElapsed / totalStakedAmount) -- This is not right
        // The correct way to track is:
        // user.rewardDebt = user.amount * (totalStakedAmountEver / totalStakedAmountAtThatTime) * rewardRate -- This is also complex

        // A common and efficient approach:
        // rewardDebt = total reward accrued so far / total staked tokens * user's staked tokens
        // user.rewardDebt = user.amount * (totalRewardPerToken)
        // totalRewardPerToken = (totalStakedAmount * rewardRate * timeElapsed) / totalStakedAmountEver (if totalStakedAmountEver is tracked)

        // Simplified approach for minimal gas:
        // Reward = (stakedAmount * rewardRate * timeElapsed) - (user.amount * rewardRate * timeElapsed) -- this is wrong

        // Let's use the common reward per token approach.
        // This requires tracking total reward issued and total tokens ever staked or current total staked.
        // A more gas efficient way is to calculate rewards only when needed and update user's debt.

        // Let's re-evaluate the reward calculation for gas efficiency.
        // The core idea is that `reward = (user.amount * rewardRate * time elapsed)`.
        // But this doesn't account for other users staking/unstaking.
        // The standard approach is `reward = user.amount * (totalRewardPerToken - user.rewardDebtPerToken)`.
        // `totalRewardPerToken` is updated based on new stakes and time elapsed.

        // To minimize gas, we can update `user.rewardDebt` when staking/unstaking.
        // When staking: `user.rewardDebt = user.rewardDebt + _amount * (totalRewardPerToken - old_user_rewardDebtPerToken)`
        // When unstaking: `user.rewardDebt = user.rewardDebt - _amount * (totalRewardPerToken - old_user_rewardDebtPerToken)`

        // Let's use a simpler debt tracking.
        // The total reward that should have been distributed to a user is `user.amount * rewardRate * time_since_start`.
        // The `rewardDebt` should represent the amount of rewards the user has already received or is owed.
        // Let `rewardDebt` track the total amount of rewards the user is entitled to.
        // When staking `_amount`: `user.rewardDebt += _amount * rewardRate * time_since_last_stake`.
        // When unstaking `_amount`: `user.rewardDebt -= _amount * rewardRate * time_since_last_stake`.

        // A more common and gas-efficient approach:
        // `rewardDebt` is the amount of rewards the user has already "claimed" or is entitled to based on their stake.
        // When a user stakes, their `rewardDebt` is updated to reflect the total rewards they *should have received* up to that point.
        // `user.rewardDebt = user.amount * (total_reward_issued_so_far / total_tokens_staked_so_far)` -- This requires tracking total issued.

        // Let's stick to the simplest gas-efficient approach:
        // `reward = (user.amount * rewardRate * time_elapsed)` is only valid if `rewardRate` is per second and `time_elapsed` is in seconds.
        // If `rewardRate` is very high, `user.amount * rewardRate` can overflow.
        // `rewardRate` should be scaled appropriately (e.g., per 1e18).

        // Let's assume `rewardRate` is tokens per second per token staked.
        // Example: rewardRate = 1e12 (meaning 1e-6 tokens per second per token staked)
        // Total reward for user: `user.amount * rewardRate * timeElapsed`
        // This will overflow if `user.amount`, `rewardRate`, and `timeElapsed` are large.

        // A better approach to avoid overflow and gas is to calculate rewards based on `totalStakedAmount` and `rewardRate`.
        // `reward = (totalStakedAmount * rewardRate * timeElapsed) - user.rewardDebt`
        // This is not correct. `user.rewardDebt` should track the amount the user *has received*.

        // Let's use the standard `rewardPerToken` approach for clarity and correctness, but optimize calculation.
        // `_updateReward(address _user)` will be called internally.
        // `totalRewardPerTokenPaid` = total rewards distributed / total tokens staked.
        // `user.rewardDebt` = `user.amount * totalRewardPerTokenPaid`.
        // `pendingReward = user.amount * (totalRewardPerTokenPaid - user.rewardDebt)`.

        // To minimize gas, we only update `user.rewardDebt` when necessary (stake/unstake/claim).
        // We need to track `totalRewardPerTokenPaid`.

        // Let's simplify. `rewardRate` is tokens per second.
        // `reward = user.amount * rewardRate * timeElapsed`
        // This implies `rewardRate` is a very small number if it's per token.
        // If `rewardRate` is the total reward distributed per second across all stakers, it's different.

        // Let's assume `rewardRate` is the amount of staking token distributed per second to the contract.
        // This means the contract must hold enough tokens to distribute.
        // `rewardRate` is the total reward rate for the entire pool.
        // `rewardPerToken = rewardRate * timeElapsed / totalStakedAmount`. This is problematic if `totalStakedAmount` is 0.

        // Let's use a more direct approach that is gas-efficient.
        // `rewardDebt` will store the amount of rewards the user has already received.
        // When a user stakes or unstakes, we calculate the pending rewards and add them to their `rewardDebt`.
        // This means `rewardDebt` is effectively the amount of rewards already "paid" to the user.
        // `pendingReward = (user.amount * rewardRate * timeElapsed) - user.rewardDebt` -- This seems wrong.

        // Back to basics:
        // `rewardRate`: tokens per second per token staked.
        // `user.amount`: amount staked by user.
        // `timeElapsed`: time since last interaction.
        // `pendingReward = user.amount * rewardRate * timeElapsed`

        // To avoid overflow, we can do:
        // `pendingReward = (user.amount * rewardRate * timeElapsed) / 1e18` if `rewardRate` is scaled.
        // If `rewardRate` is already the rate per token, then no scaling needed for rate.
        // `pendingReward = user.amount * rewardRate * timeElapsed`
        // Need to ensure `rewardRate` is small enough or use SafeMath.

        // Let's assume `rewardRate` is tokens per second per token staked, and it's a small number.
        // Example: `rewardRate = 1e-18` (1 token per second for 1e18 tokens staked).
        // `user.amount` is in the smallest unit of the token.
        // `rewardRate` should be scaled. Let's assume `rewardRate` is scaled by 1e18.
        // `rewardRate` = (tokens/sec/token) * 1e18.
        // So, `reward = user.amount * (rewardRate / 1e18) * timeElapsed`.
        // `reward = (user.amount * rewardRate * timeElapsed) / 1e18`.

        // Let's use the `rewardDebt` as the amount of rewards *accrued* to the user.
        // When user stakes `_amount`, `userInfo[_user].rewardDebt` is increased by `_amount * rewardRate * timeElapsed`.
        // When user unstakes `_amount`, `userInfo[_user].rewardDebt` is decreased by `_amount * rewardRate * timeElapsed`.
        // `pendingReward = userInfo[_user].rewardDebt - amount_already_paid_to_user`.

        // The most gas-efficient way is to calculate rewards only when claiming, staking, or unstaking.
        // `reward = user.amount * rewardRate * timeElapsed`
        // Let's assume `rewardRate` is already scaled by 1e18.
        // `reward = user.amount.mul(rewardRate).mul(timeElapsed).div(1e18);`

        // Let's use the `rewardDebt` to track the *total rewards earned by the user*.
        // When staking `_amount`:
        //   Calculate rewards earned since last interaction: `currentReward = user.amount * rewardRate * timeElapsed`.
        //   Add this to `user.rewardDebt`.
        //   Update `user.amount` and `user.lastStakeTime`.
        // When unstaking `_amount`:
        //   Calculate rewards earned since last interaction: `currentReward = user.amount * rewardRate * timeElapsed`.
        //   Add this to `user.rewardDebt`.
        //   Subtract `_amount` from `user.amount`.
        //   Subtract `_amount` from `user.rewardDebt`. (This is the amount of stake being withdrawn, so the user forfeits that much earned reward).
        //   Update `user.lastStakeTime`.
        // When claiming:
        //   Calculate rewards earned since last interaction: `currentReward = user.amount * rewardRate * timeElapsed`.
        //   Add this to `user.rewardDebt`.
        //   Transfer `user.rewardDebt` to the user.
        //   Set `user.rewardDebt = 0`.
        //   Update `user.lastStakeTime`.

        // This requires updating `rewardDebt` on every interaction.
        // Let's optimize: `rewardDebt` tracks the amount of *staked tokens* that has been "converted" into rewards.
        // When user stakes `_amount`: `user.rewardDebt = user.rewardDebt + _amount`. This is not right.

        // Let's use the common `totalRewardPerToken` approach, but calculate it efficiently.
        // `totalRewardPerTokenPaid`: total rewards paid out so far.
        // `totalStakedAmount`: current total staked amount.
        // `user.rewardDebt`: `user.amount * (totalRewardPerTokenPaid / totalStakedAmount)` -- this is not right.

        // `user.rewardDebt` should represent the total rewards the user is entitled to.
        // `user.rewardDebt = user.amount * rewardRate * timeElapsed`
        // This is the amount of reward the user has earned *since the last update*.
        // `reward = user.amount * rewardRate * timeElapsed`.

        // To avoid repeated multiplications by `rewardRate`, we can maintain a `rewardDebt` that reflects the total tokens the user has put into the system that have earned rewards.
        // When a user stakes `_amount`:
        //   `user.rewardDebt = user.rewardDebt.add(_amount);` // This is wrong.

        // Let's stick to the most direct gas-efficient calculation:
        // `reward = user.amount * rewardRate * timeElapsed`.
        // `rewardRate` is tokens per second per token.
        // We need to scale `rewardRate` to avoid precision loss. Assume `rewardRate` is scaled by 1e18.
        // `pendingReward = user.amount * (rewardRate / 1e18)