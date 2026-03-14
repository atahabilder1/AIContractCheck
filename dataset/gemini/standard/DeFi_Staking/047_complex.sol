// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingProtocol is Ownable {
    using SafeMath for uint256;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaimTime;
    }

    struct RewardToken {
        IERC20 token;
        uint256 rewardRatePerSecond; // Reward rate for 1 token staked
        uint256 totalStakedAmount;
        uint256 totalDistributed;
    }

    struct Epoch {
        uint256 startTime;
        uint256 duration;
        uint256 rewardsPerSecond; // Total rewards per second for this epoch
        uint256 totalStakedInEpoch; // Total staked amount at the beginning of the epoch
    }

    mapping(address => Stake) public stakes;
    mapping(uint256 => RewardToken) public rewardTokens;
    mapping(uint256 => Epoch) public epochs;
    uint256 public numRewardTokens;
    uint256 public numEpochs;

    // NFT contract and reward multiplier mapping
    IERC721 public nftContract;
    mapping(uint256 => uint256) public nftBoostMultiplier; // NFT ID => multiplier (e.g., 100 for 1.0x, 150 for 1.5x)

    // Staking and reward token addresses
    address public stakingTokenAddress;
    address public treasuryAddress; // Address to receive unclaimed rewards

    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardTokensAdded(uint256 indexed tokenId, address indexed tokenAddress, uint256 rewardRate);
    event EpochConfigured(uint256 indexed epochId, uint256 startTime, uint256 duration, uint256 rewardsPerSecond);
    event NFTBoostAdded(address indexed nftContractAddress, uint256 nftId, uint256 multiplier);
    event Claimed(address indexed user, uint256 totalReward);
    event RewardsDistributed(address indexed rewardTokenAddress, uint256 amount);

    modifier onlyStakingToken() {
        require(msg.sender == stakingTokenAddress, "Only staking token");
        _;
    }

    constructor(address _stakingTokenAddress, address _treasuryAddress) {
        stakingTokenAddress = _stakingTokenAddress;
        treasuryAddress = _treasuryAddress;
    }

    // --- Configuration Functions ---

    function addRewardToken(address _tokenAddress, uint256 _rewardRatePerSecond) public onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        uint256 tokenId = numRewardTokens++;
        rewardTokens[tokenId] = RewardToken({
            token: IERC20(_tokenAddress),
            rewardRatePerSecond: _rewardRatePerSecond,
            totalStakedAmount: 0,
            totalDistributed: 0
        });
        emit RewardTokensAdded(tokenId, _tokenAddress, _rewardRatePerSecond);
    }

    function configureEpoch(uint256 _epochId, uint256 _startTime, uint256 _duration, uint256 _rewardsPerSecond) public onlyOwner {
        require(_epochId != 0, "Epoch ID cannot be 0");
        require(_startTime >= block.timestamp, "Epoch start time must be in the future");
        require(_duration > 0, "Epoch duration must be greater than 0");
        require(_rewardsPerSecond > 0, "Rewards per second must be greater than 0");

        epochs[_epochId] = Epoch({
            startTime: _startTime,
            duration: _duration,
            rewardsPerSecond: _rewardsPerSecond,
            totalStakedInEpoch: 0
        });
        if (_epochId >= numEpochs) {
            numEpochs = _epochId + 1;
        }
        emit EpochConfigured(_epochId, _startTime, _duration, _rewardsPerSecond);
    }

    function setNFTContract(address _nftContractAddress) public onlyOwner {
        nftContract = IERC721(_nftContractAddress);
        emit NFTBoostAdded(_nftContractAddress, 0, 0); // Event for setting contract
    }

    function setNFTBoostMultiplier(uint256 _nftId, uint256 _multiplier) public onlyOwner {
        require(nftContract != IERC721(address(0)), "NFT contract not set");
        nftBoostMultiplier[_nftId] = _multiplier; // Multiplier is in basis points (e.g., 100 = 1.0x)
        emit NFTBoostAdded(address(nftContract), _nftId, _multiplier);
    }

    // --- Staking Functions ---

    function stake(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(stakes[msg.sender].amount == 0, "Already staked");

        IERC20(stakingTokenAddress).transferFrom(msg.sender, address(this), _amount);

        uint256 currentTime = block.timestamp;
        stakes[msg.sender] = Stake({
            amount: _amount,
            startTime: currentTime,
            lastClaimTime: currentTime
        });

        // Update epoch total staked amount if within an active epoch
        uint256 currentEpochId = getCurrentEpochId();
        if (currentEpochId > 0) {
            epochs[currentEpochId].totalStakedInEpoch = epochs[currentEpochId].totalStakedInEpoch.add(_amount);
        }

        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(stakes[msg.sender].amount >= _amount, "Insufficient staked amount");

        // Calculate and distribute rewards before unstaking
        _distributeRewards(msg.sender);

        stakes[msg.sender].amount = stakes[msg.sender].amount.sub(_amount);
        stakes[msg.sender].lastClaimTime = block.timestamp; // Update last claim time to prevent re-claiming rewards for unstaked amount

        // Update epoch total staked amount if within an active epoch
        uint256 currentEpochId = getCurrentEpochId();
        if (currentEpochId > 0) {
            epochs[currentEpochId].totalStakedInEpoch = epochs[currentEpochId].totalStakedInEpoch.sub(_amount);
        }

        IERC20(stakingTokenAddress).transfer(msg.sender, _amount);

        if (stakes[msg.sender].amount == 0) {
            delete stakes[msg.sender];
        }

        emit Unstaked(msg.sender, _amount);
    }

    function claimRewards() public {
        _distributeRewards(msg.sender);
    }

    // --- Reward Calculation and Distribution ---

    function _distributeRewards(address _user) internal {
        Stake storage stake = stakes[_user];
        require(stake.amount > 0, "No active stake");

        uint256 totalRewards = 0;
        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime.sub(stake.lastClaimTime);

        // Calculate rewards from current epoch
        uint256 currentEpochId = getCurrentEpochId();
        if (currentEpochId > 0) {
            Epoch storage currentEpoch = epochs[currentEpochId];
            uint256 timeInCurrentEpoch = currentTime < currentEpoch.startTime.add(currentEpoch.duration)
                ? currentTime.sub(currentEpoch.startTime)
                : currentEpoch.duration;

            if (timeInCurrentEpoch > 0 && currentEpoch.totalStakedInEpoch > 0) {
                uint256 userRewardsFromEpoch = (stake.amount * currentEpoch.rewardsPerSecond * timeInCurrentEpoch) / currentEpoch.totalStakedInEpoch;
                totalRewards = totalRewards.add(userRewardsFromEpoch);
            }
        }

        // Calculate rewards from past epochs
        for (uint256 epochId = getPreviousEpochId(currentEpochId); epochId > 0; epochId = getPreviousEpochId(epochId)) {
            Epoch storage pastEpoch = epochs[epochId];
            uint256 epochEndTime = pastEpoch.startTime.add(pastEpoch.duration);
            uint256 claimableEndTime = currentTime < epochEndTime ? currentTime : epochEndTime;
            uint256 timeInPastEpoch = claimableEndTime.sub(pastEpoch.startTime);

            if (timeInPastEpoch > 0 && pastEpoch.totalStakedInEpoch > 0) {
                uint256 userRewardsFromPastEpoch = (stake.amount * pastEpoch.rewardsPerSecond * timeInPastEpoch) / pastEpoch.totalStakedInEpoch;
                totalRewards = totalRewards.add(userRewardsFromPastEpoch);
            }
        }

        // Apply boost multiplier from NFTs
        uint256 boostMultiplier = _getBoostMultiplier(_user);
        totalRewards = (totalRewards * boostMultiplier) / 100; // Multiplier is in basis points

        // Distribute rewards for each reward token
        for (uint256 i = 0; i < numRewardTokens; i++) {
            RewardToken storage rewardToken = rewardTokens[i];
            if (rewardToken.rewardRatePerSecond > 0) {
                uint256 rewardAmount = (totalRewards * rewardToken.rewardRatePerSecond) / (rewardToken.rewardRatePerSecond.add(rewardToken.totalStakedAmount)); // Simplified reward distribution, can be more complex
                rewardAmount = rewardAmount.mul(timeElapsed); // Distribute rewards for the time elapsed since last claim

                if (rewardAmount > 0) {
                    require(rewardToken.token.balanceOf(address(this)) >= rewardAmount, "Insufficient reward token balance");
                    rewardToken.token.transfer(_user, rewardAmount);
                    rewardToken.totalDistributed = rewardToken.totalDistributed.add(rewardAmount);
                    emit RewardsDistributed(address(rewardToken.token), rewardAmount);
                }
            }
        }

        stake.lastClaimTime = currentTime;
        emit Claimed(_user, totalRewards);
    }

    function _getBoostMultiplier(address _user) internal view returns (uint256) {
        uint256 multiplier = 100; // Default 1.0x multiplier
        if (nftContract != IERC721(address(0))) {
            uint256 ownedNfts = nftContract.balanceOf(_user);
            for (uint256 i = 0; i < ownedNfts; i++) {
                uint256 tokenId = nftContract.tokenOfOwnerByIndex(_user, i);
                if (nftBoostMultiplier[tokenId] > multiplier) {
                    multiplier = nftBoostMultiplier[tokenId];
                }
            }
        }
        return multiplier;
    }

    function getCurrentEpochId() public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        for (uint256 i = numEpochs; i > 0; i--) {
            Epoch storage epoch = epochs[i];
            if (epoch.startTime <= currentTime && currentTime < epoch.startTime.add(epoch.duration)) {
                return i;
            }
        }
        return 0; // No active epoch
    }

    function getPreviousEpochId(uint256 _currentEpochId) public view returns (uint256) {
        if (_currentEpochId == 0) {
            // If no current epoch, find the latest past epoch
            for (uint256 i = numEpochs; i > 0; i--) {
                if (epochs[i].startTime.add(epochs[i].duration) < block.timestamp) {
                    return i;
                }
            }
            return 0;
        } else if (_currentEpochId > 1) {
            return _currentEpochId - 1;
        }
        return 0; // No previous epoch
    }

    // --- View Functions ---

    function getUserStake(address _user) public view returns (uint256 amount, uint256 startTime, uint256 lastClaimTime) {
        Stake storage stake = stakes[_user];
        return (stake.amount, stake.startTime, stake.lastClaimTime);
    }

    function getRewardTokenInfo(uint256 _tokenId) public view returns (address tokenAddress, uint256 rewardRatePerSecond, uint256 totalStakedAmount, uint256 totalDistributed) {
        RewardToken storage rewardToken = rewardTokens[_tokenId];
        return (address(rewardToken.token), rewardToken.rewardRatePerSecond, rewardToken.totalStakedAmount, rewardToken.totalDistributed);
    }

    function getEpochInfo(uint256 _epochId) public view returns (uint256 startTime, uint256 duration, uint256 rewardsPerSecond, uint256 totalStakedInEpoch) {
        Epoch storage epoch = epochs[_epochId];
        return (epoch.startTime, epoch.duration, epoch.rewardsPerSecond, epoch.totalStakedInEpoch);
    }

    function getUserPendingRewards(address _user) public view returns (uint256) {
        Stake storage stake = stakes[_user];
        if (stake.amount == 0) {
            return 0;
        }

        uint256 totalPendingRewards = 0;
        uint256 currentTime = block.timestamp;
        uint256 timeSinceLastClaim = currentTime.sub(stake.lastClaimTime);

        // Calculate rewards from current epoch
        uint256 currentEpochId = getCurrentEpochId();
        if (currentEpochId > 0) {
            Epoch storage currentEpoch = epochs[currentEpochId];
            uint256 timeInCurrentEpoch = currentTime < currentEpoch.startTime.add(currentEpoch.duration)
                ? currentTime.sub(currentEpoch.startTime)
                : currentEpoch.duration;

            if (timeInCurrentEpoch > 0 && currentEpoch.totalStakedInEpoch > 0) {
                uint256 userRewardsFromEpoch = (stake.amount * currentEpoch.rewardsPerSecond * timeInCurrentEpoch) / currentEpoch.totalStakedInEpoch;
                totalPendingRewards = totalPendingRewards.add(userRewardsFromEpoch);
            }
        }

        // Calculate rewards from past epochs
        for (uint256 epochId = getPreviousEpochId(currentEpochId); epochId > 0; epochId = getPreviousEpochId(epochId)) {
            Epoch storage pastEpoch = epochs[epochId];
            uint256 epochEndTime = pastEpoch.startTime.add(pastEpoch.duration);
            uint256 claimableEndTime = currentTime < epochEndTime ? currentTime : epochEndTime;
            uint256 timeInPastEpoch = claimableEndTime.sub(pastEpoch.startTime);

            if (timeInPastEpoch > 0 && pastEpoch.totalStakedInEpoch > 0) {
                uint256 userRewardsFromPastEpoch = (stake.amount * pastEpoch.rewardsPerSecond * timeInPastEpoch) / pastEpoch.totalStakedInEpoch;
                totalPendingRewards = totalPendingRewards.add(userRewardsFromPastEpoch);
            }
        }

        // Apply boost multiplier
        uint256 boostMultiplier = _getBoostMultiplier(_user);
        totalPendingRewards = (totalPendingRewards * boostMultiplier) / 100;

        // For simplicity, we are returning the total calculated rewards.
        // In a real-world scenario, you might want to calculate rewards per token type.
        return totalPendingRewards;
    }

    // --- Admin Functions ---

    function transferTreasury(address _newTreasury) public onlyOwner {
        treasuryAddress = _newTreasury;
    }

    function withdrawStakingTokenExcess(uint256 _amount) public onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        IERC20(stakingTokenAddress).transfer(msg.sender, _amount);
    }

    function withdrawRewardTokenExcess(uint256 _rewardTokenId, uint256 _amount) public onlyOwner {
        require(_rewardTokenId < numRewardTokens, "Invalid reward token ID");
        require(_amount > 0, "Amount must be greater than 0");
        RewardToken storage rewardToken = rewardTokens[_rewardTokenId];
        require(rewardToken.token.balanceOf(address(this)) >= _amount, "Insufficient reward token balance");
        rewardToken.token.transfer(msg.sender, _amount);
    }
}