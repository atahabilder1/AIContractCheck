// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Governance {
    struct Proposal {
        string description;
        address proposer;
        uint256 votes;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    event ProposalCreated(uint256 proposalId, string description, address proposer);
    event VoteCast(uint256 proposalId, address voter, uint256 votes);

    constructor() public {
        proposalCount = 0;
    }

    function createProposal(string memory description) public {
        Proposal memory proposal;
        proposal.description = description;
        proposal.proposer = msg.sender;
        proposal.votes = 0;
        proposals[proposalCount] = proposal;
        proposalCount++;
        emit ProposalCreated(proposalCount, description, msg.sender);
    }

    function vote(uint256 proposalId) public {
        require(proposalId < proposalCount, "Proposal does not exist");
        Proposal storage proposal = proposals[proposalId];
        proposal.votes++;
        emit VoteCast(proposalId, msg.sender, 1);
    }
}