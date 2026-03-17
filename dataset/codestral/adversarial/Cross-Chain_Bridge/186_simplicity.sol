// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    mapping(address => uint256) public balance;

    function deposit(uint256 _amount) external {
        balance[msg.sender] += _amount;
    }

    function withdraw(uint256 _amount) external {
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        balance[msg.sender] -= _amount;
    }
}