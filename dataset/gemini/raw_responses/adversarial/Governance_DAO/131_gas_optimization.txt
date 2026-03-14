```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVotes
 * @dev Interface for a token that supports historical vote snapshots (e.g., ERC20Votes).
 */
interface IVotes {
    /**
     * @dev Returns the voting power of an `account` at a specific `blockNumber`.
     * This is crucial for snapshot-based voting, preventing vote buying/selling during an active proposal.
     */
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}

/**
 * @title MinimalGovernor
 * @dev A highly gas-optimized governance contract implementing basic