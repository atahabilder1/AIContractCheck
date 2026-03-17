// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    uint256 public totalYield;
    mapping(address => uint256) public userYields;

    function addYield(uint256 _yield) public {
        totalYield += _yield;
        userYields[msg.sender] += _yield;
    }
}