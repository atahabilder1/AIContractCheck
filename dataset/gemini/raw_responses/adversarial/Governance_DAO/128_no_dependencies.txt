```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleDAO
 * @dev A basic Decentralized Autonomous Organization (DAO) contract for creating and voting on proposals.
 *      This contract includes a simplified internal token-like mechanism for voting power.
 *      It does not import any external libraries like OpenZeppelin.
 *
 *      Features:
 *      -   Simplified voting power: `balances` mapping instead of a full ERC20 contract.
 *          Tokens are minted only in the constructor to an initial owner. No transfer functionality
 *          is provided for simplicity, meaning voting power is static after initial distribution.
 *          For a real DAO, a separate ERC20