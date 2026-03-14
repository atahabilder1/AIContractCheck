// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(bytes32 => bool) public processedHashes;

    event Deposit(address indexed sender, uint256 amount, bytes32 indexed hash);
    event Withdrawal(address indexed recipient, uint256 amount, bytes32 indexed hash);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(uint256 amount, bytes32 hash) public payable {
        require(msg.value == amount, "Amount must match the deposited value");
        processedHashes[hash] = true;
        emit Deposit(msg.sender, amount, hash);
    }

    function withdraw(uint256 amount, bytes32 hash) public {
        require(processedHashes[hash], "Transaction has not been processed");
        processedHashes[hash] = false; // Mark as processed
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit Withdrawal(msg.sender, amount, hash);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}