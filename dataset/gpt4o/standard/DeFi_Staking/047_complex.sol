// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MultiRewardStaking is ReentrancyGuard {
    using SafeMath for uint256;

    struct Staker {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 lastCompounded;
    }

    struct RewardToken {
        IERC20 token;
        uint256 rewardPerEpoch;
        uint256 accRewardPerShare;
        uint256 lastUpdate;
    }

    IERC20 public stakingToken;
    IERC721 public nftCollection;
    uint256 public epochDuration;
    uint256 public boostMultiplier;
    RewardToken[] public rewardTokens;

    mapping(address => Staker) public stakers;
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256[] rewards);

    constructor(
        IERC20 _stakingToken,
        IERC721 _nftCollection,
        uint256 _epochDuration,
        uint256 _boostMultiplier
    ) {
        stakingToken = _stakingToken;
        nftCollection = _nftCollection;
        epochDuration = _epochDuration;
        boostMultiplier = _boostMultiplier;
    }

    function addRewardToken(IERC20 _token, uint256 _rewardPerEpoch) external {
        rewardTokens.push(
            RewardToken({
                token: _token,
                rewardPerEpoch: _rewardPerEpoch,
                accRewardPerShare: 0,
                lastUpdate: block.timestamp
            })
        );
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        updateRewards();
        
        stakingToken.transferFrom(msg.sender, address(this), amount);

        Staker storage staker = stakers[msg.sender];
        if (staker.stakedAmount > 0) {
            uint256 pending = staker.stakedAmount.mul(rewardTokens[0].accRewardPerShare).div(1e12).sub(staker.rewardDebt);
            staker.rewardDebt = staker.stakedAmount.mul(rewardTokens[0].accRewardPerShare).div(1e12);
            if (pending > 0) {
                rewardTokens[0].token.transfer(msg.sender, pending);
            }
        }
        
        staker.stakedAmount = staker.stakedAmount.add(amount);
        staker.rewardDebt = staker.stakedAmount.mul(rewardTokens[0].accRewardPerShare).div(1e12);
        staker.lastCompounded = block.timestamp;

        totalStaked = totalStaked.add(amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount >= amount, "Insufficient staked");

        updateRewards();

        uint256 pending = staker.stakedAmount.mul(rewardTokens[0].accRewardPerShare).div(1e12).sub(staker.rewardDebt);
        if (pending > 0) {
            rewardTokens[0].token.transfer(msg.sender, pending);
        }

        staker.stakedAmount = staker.stakedAmount.sub(amount);
        staker.rewardDebt = staker.stakedAmount.mul(rewardTokens[0].accRewardPerShare).div(1e12);

        stakingToken.transfer(msg.sender, amount);
        totalStaked = totalStaked.sub(amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        updateRewards();
        Staker storage staker = stakers[msg.sender];
        
        uint256 pending = staker.stakedAmount.mul(rewardTokens[0].accRewardPerShare).div(1e12).sub(staker.rewardDebt);
        require(pending > 0, "No rewards to claim");

        staker.rewardDebt = staker.stakedAmount.mul(rewardTokens[0].accRewardPerShare).div(1e12);
        rewardTokens[0].token.transfer(msg.sender, pending);

        emit RewardsClaimed(msg.sender, pending);
    }

    function updateRewards() internal {
        if (totalStaked == 0) {
            return;
        }
        
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            RewardToken storage rewardToken = rewardTokens[i];
            uint256 multiplier = nftCollection.balanceOf(msg.sender) > 0 ? boostMultiplier : 1;
            uint256 reward = rewardToken.rewardPerEpoch.mul(block.timestamp.sub(rewardToken.lastUpdate)).div(epochDuration).mul(multiplier);

            rewardToken.accRewardPerShare = rewardToken.accRewardPerShare.add(reward.mul(1e12).div(totalStaked));
            rewardToken.lastUpdate = block.timestamp;
        }
    }
}