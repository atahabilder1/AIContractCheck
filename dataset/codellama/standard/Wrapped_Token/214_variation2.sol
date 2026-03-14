// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WrappedToken {
    mapping(address => uint) balances;
    address[] holders;
    uint fee;

    constructor() public {
        fee = 0.01 ether;
    }

    function wrap(uint amount) public {
        require(amount > 0, "Invalid amount");
        require(msg.sender != address(0), "Invalid address");
        balances[msg.sender] += amount;
        holders.push(msg.sender);
    }

    function unwrap(uint amount) public {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        holders.push(msg.sender);
        fee = amount * 0.01 ether;
    }

    function distributeFees() public {
        require(msg.sender == address(0), "Only the contract owner can distribute fees");
        for (uint i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint amount = balances[holder] * 0.01 ether;
            fee = amount * 0.01 ether;
            holder.transfer(amount);
        }
    }

    function getBalance() public view returns (uint) {
        return balances[msg.sender];
    }
}