```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SocialRecoveryWallet {
    address public owner;
    address public pendingNewOwner; // Address proposed during recovery

    // Guardians
    mapping(address => bool) public isGuardian;
    address[] public guardians; // Storing guardians in an array to iterate for resetting approvals
    uint256 public guardianThreshold; // Minimum guardians needed for recovery

    // Recovery State
    address public recoveryInitiator; // The guardian or owner who started the current recovery
    uint256 public recoveryApprovals; // Count of guardians who approved the current recovery
    mapping(address => bool) public hasApprovedRecovery; // Track who has