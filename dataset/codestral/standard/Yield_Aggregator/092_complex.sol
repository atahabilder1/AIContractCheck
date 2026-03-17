// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YieldVault is Ownable {
    IERC20 public token;
    mapping(address => uint256) public strategyWeights;
    mapping(address => IStrategy) private strategies;

    constructor(IERC20 _token) {
        token = _token;
    }

    function setStrategyWeight(address _strategy, uint256 _weight) external onlyOwner {
        require(_strategy != address(0), "Invalid strategy");
        strategyWeights[_strategy] = _weight;
    }

    function addStrategy(IStrategy _strategy) external onlyOwner {
        strategies[_strategy] = _strategy;
    }

    function removeStrategy(address _strategy) external onlyOwner {
        delete strategies[_strategy];
        delete strategyWeights[_strategy];
    }

    function deposit(uint256 _amount) public {
        token.transferFrom(msg.sender, address(this), _amount);
        distributeToStrategies(_amount);
    }

    function withdraw(uint256 _amount) public {
        for (address strategy in strategies) {
            IStrategy(strategy).withdraw(_amount * strategyWeights[strategy] / totalWeight());
        }
        token.transfer(msg.sender, _amount);
    }

    function harvest() public {
        uint256 totalRewards = 0;
        for (address strategy in strategies) {
            totalRewards += IStrategy(strategy).harvest();
        }
        distributeToStrategies(totalRewards);
    }

    function emergencyWithdraw() public onlyOwner {
        uint256 totalBalance = token.balanceOf(address(this));
        for (address strategy in strategies) {
            IStrategy(strategy).emergencyWithdraw();
        }
        token.transfer(msg.sender, totalBalance);
    }

    function distributeToStrategies(uint256 _amount) private {
        uint256 remainingAmount = _amount;
        for (address strategy in strategies) {
            uint256 strategyDeposit = _amount * strategyWeights[strategy] / totalWeight();
            IStrategy(strategy).deposit(strategyDeposit);
            remainingAmount -= strategyDeposit;
        }
    }

    function totalWeight() private view returns (uint256) {
        uint256 sum = 0;
        for (address strategy in strategies) {
            sum += strategyWeights[strategy];
        }
        return sum;
    }
}

interface IStrategy {
    function deposit(uint256 _amount) external returns (bool);
    function withdraw(uint256 _amount) external returns (bool);
    function harvest() external returns (uint256);
    function emergencyWithdraw() external;
}