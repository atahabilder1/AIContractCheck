```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {

    enum TransactionType {
        ETH_TRANSFER,
        CONTRACT_CALL,
        ADD_OWNER,
        REMOVE_OWNER,
        CHANGE_THRESHOLD
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data; // For contract calls
        TransactionType txType;
        bool executed;
        uint256 numConfirmations;
        // Fields specific to owner/threshold changes, only relevant for those txTypes
        address newOwner;         // For ADD_OWNER/REMOVE_OWNER
        TransactionType