```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultisigWallet - A gas-optimized multisignature wallet.
/// @notice Allows multiple owners to collectively manage funds and execute transactions.
/// @dev Optimizations include custom errors, direct confirmation counter, and owner management via self-call.
contract MultisigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submission(uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event Confirmation(address indexed owner, uint256 indexed txIndex);
    event Revocation(address indexed owner, uint256 indexed txIndex