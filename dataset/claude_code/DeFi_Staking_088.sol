// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Testnet staking
contract TestnetStaking {
    address public token;
    uint256 public totalStaked;
    mapping(address => uint256) public staked;
    mapping(address => uint256) public lastStake;

    constructor(address _token) { token = _token; }

    function stake(uint256 amount) external {
        staked[msg.sender] += amount;
        totalStaked += amount;
        lastStake[msg.sender] = block.timestamp;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }

    function getReward() external {
        uint256 reward = pendingReward(msg.sender);
        lastStake[msg.sender] = block.timestamp;
        IERC20(token).transfer(msg.sender, reward);
    }

    function pendingReward(address user) public view returns (uint256) {
        if (staked[user] == 0) return 0;
        return staked[user] * (block.timestamp - lastStake[user]) / 86400;
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
