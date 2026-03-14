// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleYieldAggregator {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {}

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "Only owner can withdraw");
        payable(msg.sender).transfer(amount);
    }
}