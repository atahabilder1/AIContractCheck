```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDAO {

    // --- State Variables ---

    struct Proposal {
        uint256 id;
        address proposer;
        address target;       // The contract address to call
        uint256 value;        // The amount of Ether (in wei) to send with the call
        bytes callData;       // The encoded function call (e.g., abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount))
        string description;   // A human-readable description of the proposal
        uint256 deadline;     // Timestamp when the voting period ends
        uint256 voteCountYes; // Total 'yes' votes
        uint256 voteCountNo;  // Total 'no' votes
        bool executed;        // True if the proposal has been executed
        mapping(address => bool) hasVoted; // Tracks which members have voted for this proposal
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public nextProposalId; // Counter for unique proposal IDs

    // DAO Configuration (immutable for simplicity in MVP)
    uint256 public immutable votingPeriod;     // How long a proposal is open for voting (in seconds)
    uint256 public immutable quorumPercentage; // Percentage of total members that must vote for a proposal to be valid (e.g., 4 = 4%)
    uint256 public immutable majorityPercentage; // Percentage of 'yes' votes required among total votes cast (e.g., 51 = 51%)

    // Membership
    mapping(address => bool) public isMember; // True if address is a DAO member
    uint256 public totalMembers;              // Total count of DAO members

    address public owner; // The deployer, who initially manages members

    // --- Events ---
    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, uint256 deadline);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votesYes, uint256 votesNo);
    event ProposalExecuted(uint256 indexed proposalId, bool success);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Only members can call this function");