// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address payable public sourceChain;
    mapping(address => uint256) public balances;

    constructor(address payable _sourceChain) {
        sourceChain = _sourceChain;
    }

    function deposit(uint256 amount, address recipient) external {
        require(msg.sender == sourceChain, "Only the source chain can call this function");
        balances[recipient] += amount;
    }

    function withdraw(uint256 amount) public {
        uint256 currentBalance = balances[msg.sender];
        require(currentBalance >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        msg.sender.transfer(amount);
    }
}