// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LiquidStaking {
    address public owner;
    mapping(address => uint256) public stakedTokens;
    mapping(address => bool) public isStaker;
    mapping(address => bool) public isReceiver;
    mapping(address => bool) public isTransferable;
    uint256 public totalStakedTokens;

    constructor() public {
        owner = msg.sender;
    }

    function stake(uint256 amount) public {
        require(msg.sender == owner, "Only the owner can stake");
        require(amount > 0, "Cannot stake zero tokens");
        require(stakedTokens[msg.sender] + amount <= totalStakedTokens, "Staking would exceed the total amount");
        stakedTokens[msg.sender] += amount;
        totalStakedTokens += amount;
    }

    function unstake(uint256 amount) public {
        require(msg.sender == owner, "Only the owner can unstake");
        require(amount > 0, "Cannot unstake zero tokens");
        require(stakedTokens[msg.sender] >= amount, "Cannot unstake more than the staked amount");
        stakedTokens[msg.sender] -= amount;
        totalStakedTokens -= amount;
    }

    function transfer(address to, uint256 amount) public {
        require(msg.sender == owner, "Only the owner can transfer");
        require(amount > 0, "Cannot transfer zero tokens");
        require(stakedTokens[msg.sender] >= amount, "Cannot transfer more than the staked amount");
        stakedTokens[to] += amount;
        stakedTokens[msg.sender] -= amount;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only the owner can mint");
        require(amount > 0, "Cannot mint zero tokens");
        require(totalStakedTokens + amount <= totalSupply, "Minting would exceed the total supply");
        totalStakedTokens += amount;
        stakedTokens[to] += amount;
    }

    function burn(address from, uint256 amount) public {
        require(msg.sender == owner, "Only the owner can burn");
        require(amount > 0, "Cannot burn zero tokens");
        require(stakedTokens[from] >= amount, "Cannot burn more than the staked amount");
        stakedTokens[from] -= amount;
        totalStakedTokens -= amount;
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == owner, "Only the owner can transfer ownership");
        owner = newOwner;
    }
}