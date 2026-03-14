// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public owner;
    mapping(bytes32 => bool) public queuedTransactions;
    uint256 public delay;

    event TransactionQueued(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event TransactionExecuted(bytes32 indexed txHash);
    event TransactionCancelled(bytes32 indexed txHash);

    modifier onlyOwner() {
        require(msg.sender == owner, "Timelock: Caller is not the owner");
        _;
    }

    constructor(uint256 _delay) {
        owner = msg.sender;
        delay = _delay;
    }

    function queueTransaction(address target, uint256 value, bytes calldata data, uint256 eta) public onlyOwner {
        bytes32 txHash = keccak256(abi.encodePacked(target, value, data, eta));
        require(!queuedTransactions[txHash], "Timelock: Transaction already queued");
        require(eta >= block.timestamp + delay, "Timelock: Estimated execution time is too soon");

        queuedTransactions[txHash] = true;
        emit TransactionQueued(txHash, target, value, data, eta);
    }

    function executeTransaction(address target, uint256 value, bytes calldata data, uint256 eta) public onlyOwner {
        bytes32 txHash = keccak256(abi.encodePacked(target, value, data, eta));
        require(queuedTransactions[txHash], "Timelock: Transaction not queued");
        require(block.timestamp >= eta, "Timelock: Transaction is not yet ready to be executed");

        queuedTransactions[txHash] = false; // Mark as executed or invalid

        (bool success, ) = target.call{value: value}(data);
        require(success, "Timelock: Transaction execution failed");

        emit TransactionExecuted(txHash);
    }

    function cancelTransaction(address target, uint256 value, bytes calldata data, uint256 eta) public onlyOwner {
        bytes32 txHash = keccak256(abi.encodePacked(target, value, data, eta));
        require(queuedTransactions[txHash], "Timelock: Transaction not queued");

        queuedTransactions[txHash] = false; // Mark as cancelled
        emit TransactionCancelled(txHash);
    }

    // Fallback function to receive Ether
    receive() external payable {}
}