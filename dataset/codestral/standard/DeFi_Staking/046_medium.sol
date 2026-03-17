// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingPool {
    IERC20 public stakeToken;
    mapping(address => uint) public lockedAmount;
    mapping(address => uint) public lockTime;
    mapping(address => uint) public unlockTime;

    constructor(IERC20 _stakeToken) {
        stakeToken = _stakeToken;
    }

    function stake(uint _amount, uint _lockDuration) external {
        require(_amount > 0, "Staking amount must be greater than zero");
        stakeToken.transferFrom(msg.sender, address(this), _amount);
        lockedAmount[msg.sender] = _amount;
        lockTime[msg.sender] = block.timestamp;
        unlockTime[msg.sender] = block.timestamp + _lockDuration;
    }

    function withdraw() external {
        uint currentAmount = lockedAmount[msg.sender];
        require(currentAmount > 0, "No tokens staked");
        require(block.timestamp >= unlockTime[msg.sender], "Lockup period not ended");

        if (block.timestamp < unlockTime[msg.sender]) {
            uint penalty = currentAmount * getPenaltyPercentage() / 100;
            currentAmount -= penalty;
        }

        stakeToken.transfer(msg.sender, currentAmount);
        lockedAmount[msg.sender] = 0;
    }

    function getRewardRate(uint _lockDuration) public view returns (uint) {
        if (_lockDuration <= 3 months) return 5; // 5% reward rate for up to 3 months
        else if (_lockDuration <= 6 months) return 7; // 7% reward rate for up to 6 months
        else if (_lockDuration <= 1 year) return 10; // 10% reward rate for up to 1 year
        else return 15; // 15% reward rate for more than 1 year
    }

    function getPenaltyPercentage() public pure returns (uint) {
        return 25; // 25% penalty for early withdrawal
    }
}