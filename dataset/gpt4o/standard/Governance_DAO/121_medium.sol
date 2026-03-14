// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Governance {
    struct Proposal {
        uint256 id;
        address proposer;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 votes;
    }

    address public admin;
    uint256 public proposalCount;
    uint256 public proposalThreshold;
    uint256 public quorumVotes;
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public executionDelay;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    mapping(address => address) public delegates;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public delegatedVotes;

    event ProposalCreated(uint256 id, address proposer, address[] targets, uint256[] values, bytes[] calldatas, string description);
    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);
    event ProposalExecuted(uint256 id);

    constructor(uint256 _proposalThreshold, uint256 _quorumVotes, uint256 _votingDelay, uint256 _votingPeriod, uint256 _executionDelay) {
        admin = msg.sender;
        proposalThreshold = _proposalThreshold;
        quorumVotes = _quorumVotes;
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        executionDelay = _executionDelay;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(balances[msg.sender] + delegatedVotes[msg.sender] >= proposalThreshold, "Proposer votes below proposal threshold");

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.description = description;

        emit ProposalCreated(proposalCount, msg.sender, targets, values, calldatas, description);
        return proposalCount;
    }

    function delegate(address delegatee) public {
        address currentDelegate = delegates[msg.sender];
        if (currentDelegate != address(0)) {
            delegatedVotes[currentDelegate] -= balances[msg.sender];
        }
        delegates[msg.sender] = delegatee;
        delegatedVotes[delegatee] += balances[msg.sender];
    }

    function vote(uint256 proposalId, bool support) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.number >= proposal.startBlock && block.number <= proposal.endBlock, "Voting is closed");
        
        Receipt storage receipt = receipts[proposalId][msg.sender];
        require(!receipt.hasVoted, "Voter already voted");
        
        uint256 votes = balances[msg.sender] + delegatedVotes[msg.sender];
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }
        
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    function execute(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.number > proposal.endBlock + executionDelay, "Execution delay not met");
        require(proposal.forVotes >= quorumVotes, "Quorum not reached");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, "Transaction execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
}