// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DynamicStaking {
    address public owner;
    uint256 public constant SECONDS_IN_YEAR = 31536000;
    uint256 public totalStaked;
    uint256 public baseAPY = 500; // Base APY of 5.00%
    uint256 public rewardPool;
    
    struct Stake {
        uint256 amount;
        uint256 reward;
        uint256 lastUpdated;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function depositRewards() external payable onlyOwner {
        rewardPool += msg.value;
    }

    function calculateDynamicAPY() public view returns (uint256) {
        if (totalStaked == 0) {
            return baseAPY;
        }
        uint256 dynamicAPY = baseAPY + (rewardPool * 10000 / totalStaked) / 100;
        return dynamicAPY;
    }

    function calculateRewards(address user) public view returns (uint256) {
        Stake memory stakeInfo = stakes[user];
        uint256 timeElapsed = block.timestamp - stakeInfo.lastUpdated;
        uint256 currentAPY = calculateDynamicAPY();
        return (stakeInfo.amount * currentAPY * timeElapsed) / (SECONDS_IN_YEAR * 10000);
    }

    function stake() external payable {
        require(msg.value > 0, "Must stake more than 0");
        
        if (stakes[msg.sender].amount > 0) {
            uint256 pendingReward = calculateRewards(msg.sender);
            stakes[msg.sender].reward += pendingReward;
        }

        stakes[msg.sender].amount += msg.value;
        stakes[msg.sender].lastUpdated = block.timestamp;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function unstake() external {
        require(stakes[msg.sender].amount > 0, "No stakes found");
        
        uint256 pendingReward = calculateRewards(msg.sender);
        uint256 totalReward = stakes[msg.sender].reward + pendingReward;
        
        uint256 amountToUnstake = stakes[msg.sender].amount;
        stakes[msg.sender].amount = 0;
        stakes[msg.sender].reward = 0;
        stakes[msg.sender].lastUpdated = block.timestamp;
        totalStaked -= amountToUnstake;

        payable(msg.sender).transfer(amountToUnstake + totalReward);

        emit Unstaked(msg.sender, amountToUnstake, totalReward);
    }

    function getStakeDetails(address user) external view returns (uint256, uint256, uint256) {
        Stake memory stakeInfo = stakes[user];
        uint256 pendingReward = calculateRewards(user);
        return (stakeInfo.amount, stakeInfo.reward + pendingReward, stakeInfo.lastUpdated);
    }
}