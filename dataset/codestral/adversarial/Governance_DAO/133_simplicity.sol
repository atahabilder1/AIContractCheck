// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MVGovernance {
    struct Proposal {
        address proposer;
        string description;
        uint votesFor;
        uint votesAgainst;
        bool executed;
    }

    mapping(uint => Proposal) public proposals;
    uint public proposalCount = 0;

    function createProposal(string memory _description) external {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            proposer: msg.sender,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });
    }

    function vote(uint _proposalId, bool _support) external {
        Proposal memory proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        if (_support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
    }
}