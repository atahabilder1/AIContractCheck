```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MultiSigGovernance
 * @dev A multi-signature governance contract where proposals require approval from both
 *      token holder votes and a council of elected delegates.
 *      The contract can receive Ether and execute arbitrary calls.
 */
contract MultiSigGovernance is Ownable {
    IERC20 public immutable governanceToken;

    // --- Council Delegates ---
    address[] public delegates;
    uint256 public delegateThreshold; // The minimum number of delegates required to approve