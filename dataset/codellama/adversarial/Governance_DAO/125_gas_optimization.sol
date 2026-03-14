// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Governance {
    address public owner;
    mapping(address => uint) public balances;
    mapping(address => uint) public stakes;
    mapping(address => uint) public votes;
    uint public totalSupply;
    uint public totalStakes;

    constructor(uint _totalSupply) public {
        owner = msg.sender;
        totalSupply = _totalSupply;
    }

    function stake(uint _amount) public {
        require(msg.sender == owner, "Only the owner can stake");
        require(_amount > 0, "Invalid amount");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        stakes[msg.sender] += _amount;
        totalStakes += _amount;
        balances[msg.sender] -= _amount;
    }

    function unstake(uint _amount) public {
        require(msg.sender == owner, "Only the owner can unstake");
        require(_amount > 0, "Invalid amount");
        require(stakes[msg.sender] >= _amount, "Insufficient stake");
        stakes[msg.sender] -= _amount;
        totalStakes -= _amount;
        balances[msg.sender] += _amount;
    }

    function vote(uint _amount) public {
        require(msg.sender == owner, "Only the owner can vote");
        require(_amount > 0, "Invalid amount");
        require(stakes[msg.sender] >= _amount, "Insufficient stake");
        votes[msg.sender] += _amount;
    }

    function unvote(uint _amount) public {
        require(msg.sender == owner, "Only the owner can unvote");
        require(_amount > 0, "Invalid amount");
        require(votes[msg.sender] >= _amount, "Insufficient vote");
        votes[msg.sender] -= _amount;
    }
}