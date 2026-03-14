// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract QuadraticVotingDAO {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 voteCount;
        mapping(address => uint256) votes;
        bool executed;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public balances;

    function delegate(uint256 proposalId) public {
        uint256 votes = balances[msg.sender];
        uint256 votingPower = votes;
        proposals[proposalId].votes[msg.sender] = votingPower;
    }

    function vote(uint256 proposalId) public {
        uint256 votes = balances[msg.sender];
        uint256 votingPower = sqrt(votes);
        proposals[proposalId].votes[msg.sender] = votingPower;
        proposals[proposalId].voteCount += votingPower;
    }

    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.voteCount > 0, "Proposal does not have enough votes");
        // Implementation of proposal execution
        proposal.executed = true;
    }

    function createProposal(string memory description) public {
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposalCount++;
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = x / 2 + 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}