// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GovernanceDAO {
    struct Proposal {
        uint id;
        address proposer;
        string title;
        string description;
        uint voteCount;
        mapping(address => bool) voted;
    }

    struct Vote {
        address voter;
        uint proposalId;
        bool inFavor;
    }

    mapping(address => bool) public members;
    mapping(uint => Proposal) public proposals;
    uint public proposalCount;

    event NewProposal(uint id, address proposer, string title, string description);
    event VoteSubmitted(uint proposalId, address voter, bool inFavor);
    event ProposalPassed(uint id);
    event ProposalFailed(uint id);

    function submitProposal(string memory title, string memory description) public {
        require(members[msg.sender], "Only members can submit proposals");
        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        emit NewProposal(proposalCount, msg.sender, title, description);
    }

    function vote(uint proposalId, bool inFavor) public {
        require(members[msg.sender], "Only members can vote");
        require(proposals[proposalId].voted[msg.sender] == false, "You have already voted on this proposal");
        proposals[proposalId].voted[msg.sender] = true;
        proposals[proposalId].voteCount += 1;
        Vote storage vote = Vote(msg.sender, proposalId, inFavor);
        emit VoteSubmitted(proposalId, msg.sender, inFavor);
    }

    function getProposal(uint proposalId) public view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposalCount() public view returns (uint) {
        return proposalCount;
    }

    function isMember() public view returns (bool) {
        return members[msg.sender];
    }
}