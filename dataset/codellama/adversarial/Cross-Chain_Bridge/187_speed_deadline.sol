// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(address => uint) public balances;

    constructor() public {
        owner = msg.sender;
    }

    function transfer(address recipient, uint amount) public {
        require(msg.sender == owner, "Only the owner can transfer");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
    }

    function getBalance(address account) public view returns (uint) {
        return balances[account];
    }
}