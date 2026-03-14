// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    constructor() public {
        owner = msg.sender;
        totalSupply = 0;
    }

    function add(uint256 _amount) public {
        require(msg.sender == owner, "Only the owner can add yield");
        balances[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function remove(uint256 _amount) public {
        require(msg.sender == owner, "Only the owner can remove yield");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        totalSupply -= _amount;
    }
}