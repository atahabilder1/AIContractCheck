// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleGovernance {
    address public owner;
    uint256 public proposalCount;

    struct Proposal {
        string description;
        uint256 votes;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public hasVoted;

    event ProposalCreated(uint256 proposalId, string description);
    event Voted(uint256 proposalId, address voter);
    event ProposalExecuted(uint256 proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createProposal(string memory description) public onlyOwner {
        proposalCount++;
        proposals[proposalCount] = Proposal(description, 0, false);
        emit ProposalCreated(proposalCount, description);
    }

    function vote(uint256 proposalId) public {
        require(!hasVoted[msg.sender], "Already voted");
        require(!proposals[proposalId].executed, "Proposal already executed");

        proposals[proposalId].votes++;
        hasVoted[msg.sender] = true;
        emit Voted(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) public onlyOwner {
        require(!proposals[proposalId].executed, "Proposal already executed");
        proposals[proposalId].executed = true;
        emit ProposalExecuted(proposalId);
    }
}