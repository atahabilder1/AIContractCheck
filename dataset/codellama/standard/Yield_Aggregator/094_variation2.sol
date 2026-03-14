SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract YieldAggregator {
    struct Strategy {
        address strategyAddress;
        uint256 apy;
    }

    mapping(uint256 => Strategy) public strategies;
    uint256 public currentStrategy;

    function rotate() public {
        // Find the strategy with the highest APY
        uint256 highestApy = 0;
        Strategy highestApyStrategy;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].apy > highestApy) {
                highestApy = strategies[i].apy;
                highestApyStrategy = strategies[i];
            }
        }

        // Set the current strategy to the highest APY strategy
        currentStrategy = highestApyStrategy.strategyAddress;
    }

    function keeper() public {
        // Check if the current strategy is still the highest APY strategy
        if (currentStrategy != strategies[strategies.length - 1].strategyAddress) {
            // If not, rotate to the next highest APY strategy
            rotate();
        }
    }

    function addStrategy(address strategyAddress, uint256 apy) public {
        // Add the strategy to the mapping
        strategies[strategyAddress] = Strategy(strategyAddress, apy);

        // Update the current strategy if necessary
        if (apy > strategies[currentStrategy].apy) {
            currentStrategy = strategyAddress;
        }
    }

    function removeStrategy(address strategyAddress) public {
        // Remove the strategy from the mapping
        delete strategies[strategyAddress];

        // Update the current strategy if necessary
        if (currentStrategy == strategyAddress) {
            currentStrategy = 0;
        }
    }
}