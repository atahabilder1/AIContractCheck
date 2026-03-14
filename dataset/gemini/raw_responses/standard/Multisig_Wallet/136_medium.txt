```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint newThreshold);
    event TransactionSubmitted(uint indexed txIndex, address indexed to, uint value, bytes data);
    event Confirmation(address indexed owner, uint indexed txIndex);
    event Revocation(address indexed owner, uint indexed txIndex);
    event TransactionExecuted(uint indexed txIndex);
    event Deposit(address indexed sender, uint value);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint