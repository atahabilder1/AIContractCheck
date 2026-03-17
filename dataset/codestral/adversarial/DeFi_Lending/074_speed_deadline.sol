// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DefiLending {
    mapping(address => uint) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function borrow(uint amount) public {
        // This is a simple example and does not include interest or liquidation mechanics
        balances[msg.sender] += amount;
    }

    function repayBorrow(uint amount) public payable {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
    }
}