```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SimpleDAO
 * @dev This contract implements a basic Decentralized Autonomous Organization (DAO)
 *      with proposal creation, voting, and execution. It also includes special
 *      emergency admin functions (pause and emergency withdraw) managed by an owner.
 *      The owner of this contract acts as the emergency admin.
 *
 *      Key Features:
 *      - Proposal Creation: Users can propose actions (target contract, value, calldata).
 *      - Voting: Users can vote