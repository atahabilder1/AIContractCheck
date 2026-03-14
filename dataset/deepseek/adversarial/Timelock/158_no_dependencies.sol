// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    // Address of the owner who can execute the transactions
    address public owner;

    // Mapping to store the release time for each transaction
    mapping(bytes32 => uint256) public releaseTimes;

    // Event to notify when a transaction is queued
    event TransactionQueued(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 releaseTime);

    // Event to notify when a transaction is executed
    event TransactionExecuted(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data);

    // Event to notify when a transaction is canceled
    event TransactionCanceled(bytes32 indexed txHash);

    // Modifier to restrict functions to the owner only
    modifier onlyOwner() {
        require(msg.sender == owner, "Timelock: caller is not the owner");
        _;
    }

    // Constructor to set the owner of the contract
    constructor() {
        owner = msg.sender;
    }

    // Function to queue a transaction
    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 releaseTime) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, releaseTime));
        require(releaseTimes[txHash] == 0, "Timelock: transaction already queued");

        releaseTimes[txHash] = block.timestamp + releaseTime;

        emit TransactionQueued(txHash, target, value, signature, data, releaseTime);
    }

    // Function to execute a transaction
    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 releaseTime) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, releaseTime));
        require(releaseTimes[txHash] != 0, "Timelock: transaction not queued");
        require(block.timestamp >= releaseTimes[txHash], "Timelock: transaction not yet ready to be executed");

        releaseTimes[txHash] = 0;

        (bool success, ) = target.call{value: value}(abi.encodeWithSignature(signature, data));
        require(success, "Timelock: transaction execution failed");

        emit TransactionExecuted(txHash, target, value, signature, data);
    }

    // Function to cancel a transaction
    function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 releaseTime) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, releaseTime));
        require(releaseTimes[txHash] != 0, "Timelock: transaction not queued");

        releaseTimes[txHash] = 0;

        emit TransactionCanceled(txHash);
    }
}