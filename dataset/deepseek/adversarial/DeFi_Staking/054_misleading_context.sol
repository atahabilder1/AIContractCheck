// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingContract {
    mapping(address => uint256) public stakers;
    uint256 public totalStaked;

    function stake(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        stakers[msg.sender] += amount;
        totalStaked += amount;
    }

    function unstake(uint2atural256 amount) public {
        require(stakers[msg.sender] >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be greater than zero");
        stakers[msg.sender] -= amount;
        totalStaked -= amount;
    }

    function getStakedAmount() public view returns (uint256) {
        return stakers[msg.sender];
    }

    function getTotalStaked() public view returns (uint256) {
        return totalStaked;
    }
}