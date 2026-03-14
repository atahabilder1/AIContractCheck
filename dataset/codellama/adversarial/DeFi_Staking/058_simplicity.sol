// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    address public owner;
    uint public totalStaked;
    mapping(address => uint) public stakers;

    constructor() public {
        owner = msg.sender;
    }

    function stake(uint amount) public {
        require(msg.sender == owner, "Only the owner can stake");
        require(amount > 0, "Invalid amount");
        totalStaked += amount;
        stakers[msg.sender] += amount;
    }

    function unstake(uint amount) public {
        require(msg.sender == owner, "Only the owner can unstake");
        require(amount > 0, "Invalid amount");
        totalStaked -= amount;
        stakers[msg.sender] -= amount;
    }

    function getStaked(address staker) public view returns (uint) {
        return stakers[staker];
    }
}