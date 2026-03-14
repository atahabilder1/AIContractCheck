// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    address private owner;
    mapping(address => uint) public balances;
    uint private totalSupply;

    constructor() public {
        owner = msg.sender;
        totalSupply = 1000000;
    }

    function borrow(uint amount) public {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] + amount <= totalSupply, "Insufficient balance");
        balances[msg.sender] += amount;
        totalSupply -= amount;
    }

    function repay(uint amount) public {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        totalSupply += amount;
    }

    function getTotalSupply() public view returns (uint) {
        return totalSupply;
    }
}