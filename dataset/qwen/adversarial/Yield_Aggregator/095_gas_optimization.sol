// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IYieldSource {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract YieldAggregator {
    IYieldSource public yieldSource;
    address public owner;

    constructor(address _yieldSource) {
        yieldSource = IYieldSource(_yieldSource);
        owner = msg.sender;
    }

    function deposit(uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        yieldSource.deposit(amount);
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        yieldSource.withdraw(amount);
    }

    function balance() external view returns (uint256) {
        return yieldSource.balanceOf(address(this));
    }
}