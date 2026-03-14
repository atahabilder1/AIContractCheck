// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiDEX {
    mapping(address => uint) public balances;
    mapping(address => uint) public allowances;

    event Deposit(address indexed from, uint amount);
    event Withdrawal(address indexed to, uint amount);
    event Swap(address indexed from, address indexed to, uint amount);

    function deposit(uint amount) public {
        require(msg.sender == tx.origin, "Only EOA can deposit");
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        emit Withdrawal(msg.sender, amount);
    }

    function swap(address to, uint amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(allowances[msg.sender][to] >= amount, "Insufficient allowance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Swap(msg.sender, to, amount);
    }
}