// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    struct Yield {
        uint256 yield;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 interestRate;
    }

    mapping (address => Yield) public yields;

    function updateYield(address _token, uint256 _yield) public {
        Yield storage yield = yields[_token];
        yield.yield = _yield;
        yield.totalSupply += _yield;
        yield.totalBorrow += _yield;
        yield.interestRate = _yield / (yield.totalSupply * yield.totalBorrow);
    }

    function getYield(address _token) public view returns (uint256) {
        return yields[_token].yield;
    }

    function getTotalSupply(address _token) public view returns (uint256) {
        return yields[_token].totalSupply;
    }

    function getTotalBorrow(address _token) public view returns (uint256) {
        return yields[_token].totalBorrow;
    }

    function getInterestRate(address _token) public view returns (uint256) {
        return yields[_token].interestRate;
    }
}