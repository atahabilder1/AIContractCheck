```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IERC20Votes
 * @dev This interface is inspired by OpenZeppelin's ERC20Votes,
 *      providing a `getPastVotes` function crucial for token-weighted governance
 *      where voting power is snapshotted at a specific block.
 */
interface IERC20Votes {
    /**
     * @dev Returns the amount of votes that `account` had at the end of `blockNumber`.
     * @param account