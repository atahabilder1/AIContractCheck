// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingProtocol is Ownable {
    using SafeMath for uint256;

    // Define the reward tokens and their respective addresses here
    IERC20[] public rewardTokens;

    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public boostMultipliers;

    uint256 public epochDuration;
    uint256 public lastEpochTime;

    constructor(IERC20[] memory _rewardTokens, uint256 _epochDuration) {
        rewardTokens = _rewardTokens;
        epochDuration = _epochDuration;
        lastEpochTime = block.timestamp;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Staking amount must be greater than zero");

        stakedAmounts[msg.sender] += amount;
        // Assuming there's a function to calculate boost multiplier in an NFT contract
        boostMultipliers[msg.sender] = nftContract.calculateBoost(msg.sender);
    }

    function unstake(uint256 amount) public {
        require(amount > 0, "Unstaking amount must be greater than zero");
        require(stakedAmounts[msg.sender] >= amount, "Insufficient staked balance");

        stakedAmounts[msg.sender] -= amount;
    }

    function claimRewards() public {
        uint256 currentTime = block.timestamp;
        require(currentTime - lastEpochTime >= epochDuration, "Not enough time has passed since the last epoch");

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            IERC20 token = rewardTokens[i];
            uint256 reward = calculateReward(token);
            token.transfer(msg.sender, reward);
        }

        lastEpochTime = currentTime;
    }

    function calculateReward(IERC20 token) private view returns (uint256) {
        uint256 totalStakedAmount = getTotalStakedAmount();
        uint256 rewardRate = getRewardRate(token);
        uint256 timePassed = block.timestamp - lastEpochTime;
        uint256 userBoost = boostMultipliers[msg.sender];

        return (rewardRate * stakedAmounts[msg.sender] * userBoost / totalStakedAmount) * timePassed / epochDuration;
    }

    function getTotalStakedAmount() private view returns (uint256) {
        uint256 total = 0;
        for (address account in stakedAmounts) {
            total += stakedAmounts[account];
        }
        return total;
    }

    // Define functions to set reward rates and epoch duration here
}