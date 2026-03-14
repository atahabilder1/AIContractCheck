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
    function getUnpaidHarvest() external view returns (uint256);
}

contract YieldAggregator is Ownable {
    using SafeMath for uint256;

    IERC20 public underlyingToken;
    mapping(address => IStrategy) public strategies;
    mapping(address => bool) public whitelistedStrategies;

    event StrategyAdded(address strategyAddress);
    event StrategyRemoved(address strategyAddress);
    event StrategyWhitelisted(address strategyAddress);
    event StrategyUnwhitelisted(address strategyAddress);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event Harvested(address indexed strategy, uint256 harvestedAmount);

    constructor(address _underlyingTokenAddress) {
        underlyingToken = IERC20(_underlyingTokenAddress);
    }

    function addStrategy(address _strategyAddress) public onlyOwner {
        require(_strategyAddress != address(0), "YieldAggregator: Invalid strategy address");
        require(strategies[_strategyAddress] == IStrategy(address(0)), "YieldAggregator: Strategy already added");

        strategies[_strategyAddress] = IStrategy(_strategyAddress);
        emit StrategyAdded(_strategyAddress);
    }

    function removeStrategy(address _strategyAddress) public onlyOwner {
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");

        strategies[_strategyAddress] = IStrategy(address(0));
        whitelistedStrategies[_strategyAddress] = false; // Unwhitelist if removed
        emit StrategyRemoved(_strategyAddress);
    }

    function whitelistStrategy(address _strategyAddress) public onlyOwner {
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");
        require(!whitelistedStrategies[_strategyAddress], "YieldAggregator: Strategy already whitelisted");

        whitelistedStrategies[_strategyAddress] = true;
        emit StrategyWhitelisted(_strategyAddress);
    }

    function unwhitelistStrategy(address _strategyAddress) public onlyOwner {
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");
        require(whitelistedStrategies[_strategyAddress], "YieldAggregator: Strategy not whitelisted");

        whitelistedStrategies[_strategyAddress] = false;
        emit StrategyUnwhitelisted(_strategyAddress);
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, "YieldAggregator: Deposit amount must be greater than zero");
        require(underlyingToken.balanceOf(address(this)) >= _amount, "YieldAggregator: Insufficient balance in aggregator");

        underlyingToken.transferFrom(msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "YieldAggregator: Withdraw amount must be greater than zero");
        require(underlyingToken.balanceOf(address(this)) >= _amount, "YieldAggregator: Insufficient balance in aggregator");

        underlyingToken.transfer(msg.sender, _amount);
        emit Withdrawal(msg.sender, _amount);
    }

    function depositToStrategy(address _strategyAddress, uint256 _amount) public {
        require(whitelistedStrategies[_strategyAddress], "YieldAggregator: Strategy not whitelisted");
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");
        require(_amount > 0, "YieldAggregator: Deposit amount must be greater than zero");
        require(underlyingToken.balanceOf(address(this)) >= _amount, "YieldAggregator: Insufficient balance in aggregator");

        underlyingToken.transferFrom(msg.sender, address(_strategyAddress), _amount);
        strategies[_strategyAddress].deposit(_amount);
    }

    function withdrawFromStrategy(address _strategyAddress, uint256 _amount) public {
        require(whitelistedStrategies[_strategyAddress], "YieldAggregator: Strategy not whitelisted");
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");
        require(_amount > 0, "YieldAggregator: Withdraw amount must be greater than zero");

        strategies[_strategyAddress].withdraw(_amount);
        underlyingToken.transfer(msg.sender, _amount);
    }

    function harvestFromStrategy(address _strategyAddress) public {
        require(whitelistedStrategies[_strategyAddress], "YieldAggregator: Strategy not whitelisted");
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");

        uint256 harvestedAmount = strategies[_strategyAddress].harvest();
        emit Harvested(_strategyAddress, harvestedAmount);
    }

    function harvestAllStrategies() public {
        for (uint i = 0; i < 256; i++) { // Iterate through a reasonable range, or implement a better way to track strategies
            address strategyAddr = address(uint160(i)); // This is a naive way to iterate and should be improved
            if (strategies[strategyAddr] != IStrategy(address(0)) && whitelistedStrategies[strategyAddr]) {
                strategies[strategyAddr].harvest();
            }
        }
    }

    function getStrategyBalance(address _strategyAddress) public view returns (uint256) {
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");
        return strategies[_strategyAddress].getBalance();
    }

    function getStrategyUnpaidHarvest(address _strategyAddress) public view returns (uint256) {
        require(strategies[_strategyAddress] != IStrategy(address(0)), "YieldAggregator: Strategy not found");
        return strategies[_strategyAddress].getUnpaidHarvest();
    }

    function getAggregatorBalance() public view returns (uint256) {
        return underlyingToken.balanceOf(address(this));
    }
}