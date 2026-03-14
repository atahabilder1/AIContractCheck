// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiRewardStaking is Ownable {
    struct Stake {
        uint256 amount;
        uint256 stakeTime;
        uint256 lastClaimTime;
        uint256[] rewardDebt;
    }

    struct RewardPool {
        IERC20 rewardToken;
        uint256 rewardPerEpoch;
        uint256 lastEpoch;
        uint256 accumulatedRewardPerShare;
    }

    IERC20 public stakingToken;
    IERC721 public nftToken;
    uint256 public epochDuration;

    mapping(address => Stake) public stakes;
    mapping(uint256 => uint256) public nftBoostMultiplier;
    RewardPool[] public rewardPools;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, address indexed rewardToken, uint256 amount);

    constructor(
        IERC20 _stakingToken,
        IERC721 _nftToken,
        uint256 _epochDuration
    ) {
        stakingToken = _stakingToken;
        nftToken = _nftToken;
        epochDuration = _epochDuration;
    }

    function addRewardPool(IERC20 _rewardToken, uint256 _rewardPerEpoch) external onlyOwner {
        rewardPools.push(RewardPool({
            rewardToken: _rewardToken,
            rewardPerEpoch: _rewardPerEpoch,
            lastEpoch: block.timestamp,
            accumulatedRewardPerShare: 0
        }));
    }

    function setNftBoostMultiplier(uint256 _tokenId, uint256 _multiplier) external onlyOwner {
        nftBoostMultiplier[_tokenId] = _multiplier;
    }

    function stake(uint256 _amount) external {
        _updatePools();
        Stake storage userStake = stakes[msg.sender];
        if (userStake.amount > 0) {
            _claimRewards(userStake);
        }
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        userStake.amount += _amount;
        userStake.stakeTime = block.timestamp;
        userStake.lastClaimTime = block.timestamp;
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        _updatePools();
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount >= _amount, "Insufficient staked amount");
        _claimRewards(userStake);
        userStake.amount -= _amount;
        stakingToken.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claimRewards() external {
        _updatePools();
        Stake storage userStake = stakes[msg.sender];
        _claimRewards(userStake);
    }

    function _updatePools() internal {
        for (uint256 i = 0; i < rewardPools.length; i++) {
            RewardPool storage pool = rewardPools[i];
            uint256 epochsPassed = (block.timestamp - pool.lastEpoch) / epochDuration;
            if (epochsPassed == 0) continue;
            pool.lastEpoch += epochsPassed * epochDuration;
            uint256 totalStaked = getTotalStaked();
            if (totalStaked == 0) continue;
            uint256 reward = epochsPassed * pool.rewardPerEpoch;
            pool.rewardToken.transferFrom(msg.sender, address(this), reward);
            pool.accumulatedRewardPerShare += (reward * 1e18) / totalStaked;
        }
    }

    function _claimRewards(Stake storage userStake) internal {
        for (uint256 i = 0; i < rewardPools.length; i++) {
            RewardPool storage pool = rewardPools[i];
            uint256 accumulatedRewards = (userStake.amount * pool.accumulatedRewardPerShare) / 1e18;
            uint256 pendingRewards = accumulatedRewards - userStake.rewardDebt[i];
            if (pendingRewards > 0) {
                pool.rewardToken.transfer(msg.sender, pendingRewards);
                emit Claimed(msg.sender, address(pool.rewardToken), pendingRewards);
            }
            userStake.rewardDebt[i] = accumulatedRewards;
        }
        userStake.lastClaimTime = block.timestamp;
    }

    function getTotalStaked() public view returns (uint256) {
        uint256 total;
        for (address user; ; ) {
            Stake storage userStake = stakes[user];
            total += userStake.amount;
            if (user == address(0)) break;
        }
        return total;
    }

    function getUserBoost(address _user) public view returns (uint256) {
        uint256 boost = 1e18;
        uint256 balance = nftToken.balanceOf(_user);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = nftToken.tokenOfOwnerByIndex(_user, i);
            boost += nftBoostMultiplier[tokenId];
        }
        return boost;
    }

    function getUserPendingRewards(address _user) public view returns (uint256[] memory) {
        uint256[] memory pendingRewards = new uint256[](rewardPools.length);
        Stake storage userStake = stakes[_user];
        uint256 boost = getUserBoost(_user);
        for (uint256 i = 0; i < rewardPools.length; i++) {
            RewardPool storage pool = rewardPools[i];
            uint256 accumulatedRewards = (userStake.amount * pool.accumulatedRewardPerShare * boost) / 1e36;
            pendingRewards[i] = accumulatedRewards - userStake.rewardDebt[i];
        }
        return pendingRewards;
    }
}