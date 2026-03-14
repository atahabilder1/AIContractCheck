```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Required for MyTokenVesting

/**
 * @title MyToken
 * @dev Production-ready ERC20 token with the following features:
 *      - ERC20 standard compliance.
 *      - Governance voting capabilities (ERC20Votes) including delegation and past vote snapshots.
 *      - E