// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    address public owner;
    mapping(address => uint) public yieldRates;

    constructor() public {
        owner = msg.sender;
    }

    function updateYieldRate(address _token, uint _yieldRate) public {
        require(msg.sender == owner, "Only owner can update yield rate");
        yieldRates[_token] = _yieldRate;
    }

    function getYieldRate(address _token) public view returns (uint) {
        return yieldRates[_token];
    }
}