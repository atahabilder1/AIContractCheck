// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DAO {
    // Define the struct for Proposals
    struct Proposal {
        string description;
        uint votesFor;
        uint votesAgainst;
        bool executed;
    }

    // Array to store all proposals
    mapping(uint => Proposal) public proposals;

    // Counter for the number of proposals
    uint public numProposals;

    // Minimum percentage required for a proposal to pass
    uint public minimumPercentage = 51;

    // Mapping to store votes per user
    mapping(address => bool) public voted;

    // Modifier to ensure only voters can interact with the contract
    modifier onlyVoter() {
        require(!voted[msg.sender], "Already voted.");
        _;
    }

    // Function to create a new proposal
    function createProposal(string memory description) public {
        numProposals++;
        proposals[numProposals] = Proposal({
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });
    }

    // Function to vote for a proposal
    function vote(uint proposalId, bool support) public onlyVoter {
        require(proposalId > 0 && proposalId <= numProposals, "Invalid Proposal ID.");
        voted[msg.sender] = true;
        if (support) {
            proposals[proposalId].votesFor++;
        } else {
            proposals[proposalId].votesAgainst++;
        }
    }

    // Function to execute a proposal
    function executeProposal(uint proposalId) public {
        require(isProposalPassed(proposalId), "Proposal has not passed.");
        require(!proposals[proposalId].executed, "Proposal already executed.");
        proposals[proposalId].executed = true;
    }

    // Function to check if a proposal is passed
    function isProposalPassed(uint proposalId) public view returns (bool) {
        uint totalVotes = proposals[proposalId].votesFor + proposals[proposalId].votesAgainst;
        return (proposals[proposalId].votesFor * 100 / totalVotes) >= minimumPercentage;
    }
}