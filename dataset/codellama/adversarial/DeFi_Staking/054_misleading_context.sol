// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    address public owner;
    uint public stakingAmount;
    uint public stakingDuration;
    uint public stakingReward;
    mapping(address => uint) public stakers;

    constructor(address _owner, uint _stakingAmount, uint _stakingDuration, uint _stakingReward) public {
        owner = _owner;
        stakingAmount = _stakingAmount;
        stakingDuration = _stakingDuration;
        stakingReward = _stakingReward;
    }

    function stake(uint _amount) public {
        require(msg.sender == owner, "Only the owner can stake");
        require(_amount >= stakingAmount, "Not enough staking amount");
        require(_amount <= stakingDuration, "Staking duration exceeded");

        stakers[msg.sender] = _amount;
    }

    function withdraw(uint _amount) public {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(_amount >= stakingAmount, "Not enough staking amount");
        require(_amount <= stakingDuration, "Staking duration exceeded");

        stakers[msg.sender] -= _amount;
    }

    function getStakingReward() public view returns (uint) {
        return stakingReward;
    }
}