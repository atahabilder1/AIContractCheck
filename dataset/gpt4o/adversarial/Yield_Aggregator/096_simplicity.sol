// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IYieldFarm {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
}

contract SimpleYieldAggregator {
    IYieldFarm public yieldFarm;
    mapping(address => uint256) public balances;

    constructor(address _yieldFarm) {
        yieldFarm = IYieldFarm(_yieldFarm);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        balances[msg.sender] += amount;
        yieldFarm.deposit(amount);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        yieldFarm.withdraw(amount);
    }

    function claimRewards() external {
        yieldFarm.getReward();
    }
}