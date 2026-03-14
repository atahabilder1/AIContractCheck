```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDAO {
    // The deployer of the contract, initially has administrative control for member management.
    // In a fully decentralized DAO, even member management would be via proposals.
    // For "simplest possible", this admin role is kept for initial setup.
    address public owner;

    // Mapping to track if an address is a member, and thus has voting power.
    // Each member gets 1 vote.
    mapping(address => bool) public isMember;
    uint256 public memberCount; // Total number of active members.

    uint256 public proposalCount; // Total number of proposals