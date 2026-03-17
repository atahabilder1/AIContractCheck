// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    uint256[] public yields;

    function addYield(uint256 _yield) external {
        yields.push(_yield);
    }

    function getTotalYield() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < yields.length; i++) {
            total += yields[i];
        }
        return total;
    }
}