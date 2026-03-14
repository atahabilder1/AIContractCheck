// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    // List of owners
    address[] public owners;
    // Threshold for confirmation
    uint public threshold;
    // Map of transaction hash to confirmation count
    mapping(bytes32 => uint) public confirmations;

    constructor(address[] memory _owners, uint _threshold) public {
        owners = _owners;
        threshold = _threshold;
    }

    function submitTransaction(address to, uint value, bytes memory data) public {
        // Generate transaction hash
        bytes32 hash = keccak256(abi.encode(to, value, data));
        // Add transaction to confirmation map
        confirmations[hash] = 0;
        // Emit event for new transaction
        emit SubmitTransaction(hash, to, value, data);
    }

    function confirmTransaction(bytes32 hash) public {
        // Check if transaction has already been confirmed
        require(confirmations[hash] < threshold, "Transaction already confirmed");
        // Check if sender is an owner
        require(owners.contains(msg.sender), "Only owners can confirm transactions");
        // Increment confirmation count
        confirmations[hash]++;
        // Emit event for confirmation
        emit ConfirmTransaction(hash, confirmations[hash]);
        // If threshold reached, execute transaction
        if (confirmations[hash] >= threshold) {
            executeTransaction(hash);
        }
    }

    function executeTransaction(bytes32 hash) public {
        // Check if transaction has been confirmed
        require(confirmations[hash] >= threshold, "Transaction not yet confirmed");
        // Execute transaction
        address to = hash.to;
        uint value = hash.value;
        bytes memory data = hash.data;
        to.transfer(value);
        // Emit event for execution
        emit ExecuteTransaction(hash, to, value, data);
    }
}