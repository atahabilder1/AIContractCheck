// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiStrategyYieldVault {
    address public owner;
    uint256 public totalValue;
    mapping(address => uint256) public strategyAllocationWeights;
    mapping(address => uint256) public harvestRewards;
    mapping(address => uint256) public performanceFees;
    mapping(address => uint256) public emergencyWithdrawalAmounts;

    constructor(address _owner) public {
        owner = _owner;
        totalValue = 0;
    }

    function setStrategyAllocationWeights(address[] memory _strategies, uint256[] memory _allocationWeights) public {
        require(msg.sender == owner, "Only owner can set strategy allocation weights");
        require(_strategies.length == _allocationWeights.length, "Invalid input");

        for (uint256 i = 0; i < _strategies.length; i++) {
            strategyAllocationWeights[_strategies[i]] = _allocationWeights[i];
        }
    }

    function harvestRewards(address _strategy) public {
        require(msg.sender == owner, "Only owner can harvest rewards");

        uint256 rewardAmount = harvestRewards[_strategy];
        if (rewardAmount > 0) {
            totalValue += rewardAmount;
            harvestRewards[_strategy] = 0;
        }
    }

    function performanceFees(address _strategy) public {
        require(msg.sender == owner, "Only owner can collect performance fees");

        uint256 feeAmount = performanceFees[_strategy];
        if (feeAmount > 0) {
            totalValue -= feeAmount;
            performanceFees[_strategy] = 0;
        }
    }

    function emergencyWithdrawal(address _strategy) public {
        require(msg.sender == owner, "Only owner can emergency withdraw");

        uint256 withdrawalAmount = emergencyWithdrawalAmounts[_strategy];
        if (withdrawalAmount > 0) {
            totalValue -= withdrawalAmount;
            emergencyWithdrawalAmounts[_strategy] = 0;
        }
    }
}