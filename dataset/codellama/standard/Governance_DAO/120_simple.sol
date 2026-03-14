// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DAO {
    // State variables
    address public owner;
    mapping(address => uint) public balances;
    mapping(uint => Proposal) public proposals;
    uint public proposalCount;

    // Proposal struct
    struct Proposal {
        address proposer;
        string description;
        uint voteCount;
    }

    // Modifiers
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Events
    event ProposalCreated(uint indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint indexed proposalId, address indexed voter, uint voteCount);

    // Constructor
    constructor() public {
        owner = msg.sender;
        proposalCount = 0;
    }

    // Create a new proposal
    function createProposal(string memory _description) public {
        require(bytes(_description).length > 0, "Description cannot be empty");

        Proposal memory proposal;
        proposal.proposer = msg.sender;
        proposal.description = _description;
        proposal.voteCount = 0;

        proposals[proposalCount] = proposal;

        emit ProposalCreated(proposalCount, msg.sender, _description);

        proposalCount++;
    }

    // Vote on a proposal
    function vote(uint _proposalId) public {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(msg.sender == owner, "Only the owner can call this function");

        Proposal storage proposal = proposals[_proposalId];
        proposal.voteCount++;

        emit VoteCast(_proposalId, msg.sender, proposal.voteCount);
    }
}