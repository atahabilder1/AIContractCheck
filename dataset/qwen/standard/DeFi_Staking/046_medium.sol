// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract StakingPool {
    uint256 public constant MIN_LOCK_DURATION = 30 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant BASE_REWARD_RATE = 10; // 10% annual
    uint256 public constant PENALTY_RATE = 5; // 5% penalty

    struct Stake {
        uint256 amount;
        uint256 lockTime;
        uint256 endTime;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 endTime);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    function stake(uint256 _amount, uint256 _lockDuration) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_lockDuration >= MIN_LOCK_DURATION && _lockDuration <= MAX_LOCK_DURATION, "Lock duration out of range");

        uint256 endTime = block.timestamp + _lockDuration;
        uint256 rewardRate = BASE_REWARD_RATE + ((_lockDuration / 30 days) * 5); // Increase by 5% for each additional month

        stakes[msg.sender] = Stake({
            amount: _amount,
            lockTime: _lockDuration,
            endTime: endTime
        });

        emit Staked(msg.sender, _amount, endTime);
    }

    function withdraw() external {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake found");

        uint256 reward;
        if (block.timestamp < userStake.endTime) {
            // Apply penalty for early withdrawal
            reward = (userStake.amount * (BASE_REWARD_RATE - PENALTY_RATE)) / 100;
        } else {
            // Calculate reward based on lock duration
            uint256 duration = (block.timestamp - (userStake.endTime - userStake.lockTime)) / 30 days;
            uint256 rewardRate = BASE_REWARD_RATE + (duration * 5);
            reward = (userStake.amount * rewardRate) / 100;
        }

        uint256 totalAmount = userStake.amount + reward;
        delete stakes[msg.sender];

        (bool success, ) = msg.sender.call{value: totalAmount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, userStake.amount, reward);
    }

    receive() external payable {}
}