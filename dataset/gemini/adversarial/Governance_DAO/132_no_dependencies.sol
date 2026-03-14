```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDAO {

    // --- State Variables ---
    address public owner; // Initial deployer, can set parameters

    uint public votingPeriod; // Duration of voting in seconds
    uint public quorumPercentage; // Percentage of totalShares required for quorum (e.g., 4 = 4%)
    uint public executionDelay; // Delay in seconds after successful vote before execution is possible
    uint public minProposalThreshold; // Minimum shares required to create a proposal
    uint public constant EXECUTION_GRACE_PERIOD = 7 days; // Time after eta that a queued proposal can still be executed

    uint public totalShares; //