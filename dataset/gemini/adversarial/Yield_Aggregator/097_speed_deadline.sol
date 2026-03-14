// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IStrategy {
    function deposit(uint256 _amount) external returns (uint256);
    function withdraw(uint256 _amount) external returns (uint256);
    function harvest() external returns (uint256);
    function getBalance() external view returns (uint256);
    function getCompoundedBalance() external view returns (uint256);
    function getUnderlyingToken() external view returns (address);
    function getRewardTokens() external view returns (address[] memory);
}

contract YieldAggregator is Ownable {
    using SafeMath for uint256;

    address public vaultToken; // The token users deposit to earn yield
    address[] public strategies; // Addresses of registered strategies

    mapping(address => bool) public isStrategy;

    event StrategyRegistered(address indexed strategyAddress);
    event StrategyDeregistered(address indexed strategyAddress);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Harvest(address indexed strategy, uint256 rewardAmount);

    constructor(address _vaultToken) {
        vaultToken = _vaultToken;
    }

    function registerStrategy(address _strategyAddress) public onlyOwner {
        require(!isStrategy[_strategyAddress], "Strategy already registered");
        IStrategy strategy = IStrategy(_strategyAddress);
        require(strategy.getUnderlyingToken() == vaultToken, "Strategy token mismatch");

        strategies.push(_strategyAddress);
        isStrategy[_strategyAddress] = true;
        emit StrategyRegistered(_strategyAddress);
    }

    function deregisterStrategy(address _strategyAddress) public onlyOwner {
        require(isStrategy[_strategyAddress], "Strategy not registered");

        // Find and remove strategy from array (inefficient for large arrays but fast for hackathon)
        for (uint i = 0; i < strategies.length; i++) {
            if (strategies[i] == _strategyAddress) {
                strategies[i] = strategies[strategies.length - 1];
                strategies.pop();
                break;
            }
        }

        isStrategy[_strategyAddress] = false;
        emit StrategyDeregistered(_strategyAddress);
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        IERC20(vaultToken).transferFrom(msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        uint256 totalBalance = IERC20(vaultToken).balanceOf(address(this));
        require(_amount <= totalBalance, "Insufficient balance");

        // Simple withdrawal logic: take from strategies proportionally
        // For a hackathon, we can simplify this. A real implementation needs more robust allocation.
        // Here, we'll just try to withdraw from the first available strategy.
        // A better approach would be to track user deposits and withdraw from strategies based on that.

        if (strategies.length > 0) {
            address strategyToWithdrawFrom = strategies[0]; // Simplistic choice
            IStrategy strategy = IStrategy(strategyToWithdrawFrom);
            uint256 strategyBalance = strategy.getBalance();
            uint256 amountToWithdrawFromStrategy = _amount > strategyBalance ? strategyBalance : _amount;

            if (amountToWithdrawFromStrategy > 0) {
                strategy.withdraw(amountToWithdrawFromStrategy);
                IERC20(vaultToken).transfer(msg.sender, amountToWithdrawFromStrategy);
                emit Withdraw(msg.sender, amountToWithdrawFromStrategy);
                // If we withdrew less than requested, the rest is still in the vault contract.
                // A real system would need to rebalance or handle this.
            } else {
                // If strategy has no balance, we can't fulfill the withdrawal from it.
                // This highlights the need for better strategy management.
                revert("No funds in selected strategy to withdraw");
            }
        } else {
            revert("No strategies available");
        }
    }

    function harvestAll() public onlyOwner {
        for (uint i = 0; i < strategies.length; i++) {
            IStrategy strategy = IStrategy(strategies[i]);
            address[] memory rewardTokens = strategy.getRewardTokens();
            for (uint j = 0; j < rewardTokens.length; j++) {
                // This is a simplified harvest. In a real scenario, you'd need to
                // claim rewards and then deposit them back into a strategy or sell them.
                // For a hackathon, we assume the strategy handles reward claiming internally.
                uint256 rewards = strategy.harvest();
                if (rewards > 0) {
                    emit Harvest(strategies[i], rewards);
                    // In a real scenario, you would want to deposit these rewards back
                    // into the strategy or a separate reward vault.
                    // For simplicity here, we'll assume the strategy's harvest() method
                    // already handles re-staking or depositing rewards.
                }
            }
        }
    }

    function getVaultToken() public view returns (address) {
        return vaultToken;
    }

    function getStrategies() public view returns (address[] memory) {
        return strategies;
    }

    function getTotalVaultBalance() public view returns (uint256) {
        return IERC20(vaultToken).balanceOf(address(this));
    }

    function getTotalStrategyBalance() public view returns (uint256) {
        uint256 total = 0;
        for (uint i = 0; i < strategies.length; i++) {
            total = total.add(IStrategy(strategies[i]).getBalance());
        }
        return total;
    }

    function getCompoundedVaultBalance() public view returns (uint256) {
        uint256 total = 0;
        for (uint i = 0; i < strategies.length; i++) {
            total = total.add(IStrategy(strategies[i]).getCompoundedBalance());
        }
        return total;
    }
}