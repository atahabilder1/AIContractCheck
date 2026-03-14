// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Governance {
    address public owner;
    mapping(address => uint256) public shares;

    constructor() public {
        owner = msg.sender;
    }

    function propose(string memory _proposal) public {
        require(msg.sender == owner, "Only the owner can propose");
        require(_proposal.length > 0, "Proposal cannot be empty");
        require(shares[msg.sender] > 0, "Proposer must have shares");

        uint256 proposalId = keccak256(abi.encode(_proposal));
        emit ProposalCreated(proposalId, _proposal);
    }

    function vote(uint256 _proposalId, bool _vote) public {
        require(msg.sender == owner, "Only the owner can vote");
        require(_proposalId > 0, "Invalid proposal ID");
        require(shares[msg.sender] > 0, "Voter must have shares");

        Proposal storage proposal = proposals[_proposalId];
        require(proposal.startBlock > 0, "Proposal must have a start block");
        require(block.number > proposal.startBlock, "Voting period not started yet");
        require(block.number < proposal.endBlock, "Voting period has ended");

        uint256 weight = shares[msg.sender];
        if (_vote) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }

        emit Voted(msg.sender, _proposalId, _vote);
    }

    function execute(uint256 _proposalId) public {
        require(msg.sender == owner, "Only the owner can execute");
        require(_proposalId > 0, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];
        require(proposal.startBlock > 0, "Proposal must have a start block");
        require(block.number > proposal.startBlock, "Execution period not started yet");
        require(block.number < proposal.endBlock, "Execution period has ended");

        if (proposal.votesFor > proposal.votesAgainst) {
            // Execute the proposal
            proposal.executed = true;
            emit Executed(msg.sender, _proposalId);
        } else {
            // Revert the proposal
            proposal.reverted = true;
            emit Reverted(msg.sender, _proposalId);
        }
    }
}

event ProposalCreated(uint256 proposalId, string proposal);
event Voted(address voter, uint256 proposalId, bool vote);
event Executed(address executor, uint256 proposalId);
event Reverted(address executor, uint256 proposalId);