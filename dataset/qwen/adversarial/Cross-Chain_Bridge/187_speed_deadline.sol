// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(address => uint256) public balances;

    event TransferInitiated(address indexed from, uint256 amount, uint256 indexed nonce);
    event TransferCompleted(address indexed to, uint256 amount, uint256 indexed nonce);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        balances[msg.sender] += amount;
        emit TransferInitiated(msg.sender, amount, block.timestamp);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        require(balances[to] >= amount, "Insufficient balance");
        balances[to] -= amount;
        payable(to).transfer(amount);
        emit TransferCompleted(to, amount, block.timestamp);
    }
}