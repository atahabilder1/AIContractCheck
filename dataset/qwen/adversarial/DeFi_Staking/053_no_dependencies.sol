// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    mapping(address => uint256) public stakedBalances;
    uint256 public totalStaked;
    uint256 public rewardRate; // Reward rate per second per wei staked
    uint256 public lastUpdateTimestamp;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(uint256 _rewardRate) {
        rewardRate = _rewardRate;
        lastUpdateTimestamp = block.timestamp;
    }

    function _updateReward(address _account) internal {
        if (_account != address(0)) {
            uint256 rewardPerTokenEarned = earned(_account);
            rewards[_account] = rewards[_account] + rewardPerTokenEarned;
            userRewardPerTokenPaid[_account] = rewardPerToken();
        }
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return 0;
        }
        return (rewardRate * (block.timestamp - lastUpdateTimestamp) * 1e18) / totalStaked;
    }

    function earned(address _account) public view returns (uint256) {
        return (stakedBalances[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18 + rewards[_account];
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "Cannot stake 0");
        _updateReward(msg.sender);
        stakedBalances[msg.sender] += _amount;
        totalStaked += _amount;
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Cannot withdraw 0");
        _updateReward(msg.sender);
        stakedBalances[msg.sender] -= _amount;
        totalStaked -= _amount;
        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() external {
        _updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        rewards[msg.sender] = 0;
        emit RewardPaid(msg.sender, reward);
    }

    function exit() external {
        withdraw(stakedBalances[msg.sender]);
        getReward();
    }
}