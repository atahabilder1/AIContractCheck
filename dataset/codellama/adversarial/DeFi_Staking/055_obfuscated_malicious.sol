// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    address private _admin;
    uint256 private _stakeAmount;
    uint256 private _minStakeTime;
    uint256 private _maxStakeTime;
    uint256 private _stakeDuration;
    uint256 private _stakeReward;
    bool private _paused;

    constructor(
        address admin,
        uint256 stakeAmount,
        uint256 minStakeTime,
        uint256 maxStakeTime,
        uint256 stakeDuration,
        uint256 stakeReward
    ) {
        _admin = admin;
        _stakeAmount = stakeAmount;
        _minStakeTime = minStakeTime;
        _maxStakeTime = maxStakeTime;
        _stakeDuration = stakeDuration;
        _stakeReward = stakeReward;
        _paused = false;
    }

    function stake(uint256 amount) external {
        require(amount >= _stakeAmount, "Invalid stake amount");
        require(msg.sender.balance >= amount, "Insufficient balance");
        require(!_paused, "Staking is paused");

        uint256 currentTime = block.timestamp;
        require(currentTime >= _minStakeTime, "Staking is not available yet");
        require(currentTime <= _maxStakeTime, "Staking has ended");

        uint256 stakeTime = currentTime - _minStakeTime;
        require(stakeTime <= _stakeDuration, "Staking period has ended");

        uint256 reward = amount * _stakeReward / 100;
        msg.sender.transfer(reward);
    }

    function withdraw() external {
        require(msg.sender == _admin, "Only the admin can withdraw");
        require(!_paused, "Staking is paused");

        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficient balance");

        msg.sender.transfer(balance);
    }

    function pause() external {
        require(msg.sender == _admin, "Only the admin can pause");
        _paused = true;
    }

    function unpause() external {
        require(msg.sender == _admin, "Only the admin can unpause");
        _paused = false;
    }
}