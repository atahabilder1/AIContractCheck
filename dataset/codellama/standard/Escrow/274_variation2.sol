// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public owner;
    mapping(address => mapping(address => uint)) public balances;

    constructor() public {
        owner = msg.sender;
    }

    function deposit(address _nftContract, uint _amount) public {
        require(msg.sender == owner, "Only the owner can deposit");
        balances[_nftContract][msg.sender] += _amount;
    }

    function withdraw(address _nftContract, uint _amount) public {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(balances[_nftContract][msg.sender] >= _amount, "Insufficient balance");
        balances[_nftContract][msg.sender] -= _amount;
    }

    function swap(address _nftContract, uint _amount) public {
        require(msg.sender == owner, "Only the owner can swap");
        require(balances[_nftContract][msg.sender] >= _amount, "Insufficient balance");
        balances[_nftContract][msg.sender] -= _amount;
        balances[_nftContract][msg.sender] += _amount;
    }
}