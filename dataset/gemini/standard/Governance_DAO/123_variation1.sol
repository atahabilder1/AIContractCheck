// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Using Ownable for initial setup of DAO parameters.

contract QuadraticVotingDAO is Ownable {
    IERC20 public immutable token;

    uint256 public proposalCounter;

    struct Proposal {
        uint256 id;
        string description;
        address target; // Target contract for execution
        bytes callData; // Calldata for target contract
        uint256 creationTime;
        uint256 votingPeriodEnd;
        uint256 yayVotes; // Sum