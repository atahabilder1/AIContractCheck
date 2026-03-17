// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

interface IDfiStrategy {
    function deposit(uint amount) external;
}

contract YieldAggregator {
    mapping(address => IDfiStrategy) strategies;
    mapping(address => AggregatorV3Interface) apyOracles;
    address[] public strategyPool;

    constructor() {}

    function addStrategy(address _strategy, address _apyOracle) external {
        strategies[_strategy] = IDfiStrategy(_strategy);
        apyOracles[_strategy] = AggregatorV3Interface(_apyOracle);
        strategyPool.push(_strategy);
    }

    function rotate() external {
        uint256 bestAPY = 0;
        address bestStrategy;

        for (uint i = 0; i < strategyPool.length; i++) {
            (, int256 apy, , , ) = apyOracles[strategyPool[i]].latestRoundData();

            if (apy > bestAPY) {
                bestAPY = apy;
                bestStrategy = strategyPool[i];
            }
        }

        require(bestStrategy != address(0), "No valid strategy found");
        IDfiStrategy(bestStrategy).deposit(address(this).balance);
    }

    receive() external payable {}
}