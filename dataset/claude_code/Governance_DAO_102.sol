// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// DAO Governance with Quadratic Voting
contract QuadraticDAO {
    address public governanceToken;

    uint256 public proposalCount;
    uint256 public votingPeriod = 3 days;
    uint256 public quorumVotes;
    uint256 public proposalThreshold;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        address target;
        bytes callData;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startBlock;
        uint256 endTime;
        bool executed;
        bool canceled;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => uint256)) public votesUsed;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    constructor(address _governanceToken, uint256 _quorumVotes, uint256 _proposalThreshold) {
        governanceToken = _governanceToken;
        quorumVotes = _quorumVotes;
        proposalThreshold = _proposalThreshold;
    }

    function propose(
        string calldata description,
        address target,
        bytes calldata callData
    ) external returns (uint256) {
        require(
            IGovernanceToken(governanceToken).balanceOf(msg.sender) >= proposalThreshold,
            "Below proposal threshold"
        );

        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.target = target;
        proposal.callData = callData;
        proposal.startBlock = block.number;
        proposal.endTime = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalCount, msg.sender, description);
        return proposalCount;
    }

    function vote(uint256 proposalId, bool support, uint256 votes) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.canceled, "Proposal canceled");

        uint256 voterBalance = IGovernanceToken(governanceToken).balanceOf(msg.sender);
        uint256 previousVotes = votesUsed[proposalId][msg.sender];
        uint256 totalVotesNeeded = previousVotes + votes;

        // Quadratic voting: cost = votes^2
        uint256 costForVotes = totalVotesNeeded * totalVotesNeeded;
        require(voterBalance >= costForVotes, "Insufficient tokens for votes");

        votesUsed[proposalId][msg.sender] = totalVotesNeeded;

        // Calculate quadratic weight
        uint256 newWeight = sqrt(totalVotesNeeded);
        uint256 oldWeight = sqrt(previousVotes);
        uint256 additionalWeight = newWeight - oldWeight;

        if (support) {
            proposal.forVotes += additionalWeight;
        } else {
            proposal.againstVotes += additionalWeight;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit VoteCast(msg.sender, proposalId, support, votes, additionalWeight);
    }

    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(proposal.forVotes > proposal.againstVotes, "Proposal defeated");
        require(proposal.forVotes >= quorumVotes, "Quorum not reached");

        proposal.executed = true;

        (bool success, ) = proposal.target.call(proposal.callData);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer, "Not proposer");
        require(!proposal.executed, "Already executed");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function getProposalState(uint256 proposalId) external view returns (string memory) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) return "Canceled";
        if (proposal.executed) return "Executed";
        if (block.timestamp <= proposal.endTime) return "Active";
        if (proposal.forVotes <= proposal.againstVotes) return "Defeated";
        if (proposal.forVotes < quorumVotes) return "Quorum Failed";
        return "Succeeded";
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function setVotingPeriod(uint256 _votingPeriod) external {
        require(msg.sender == address(this), "Only governance");
        votingPeriod = _votingPeriod;
    }

    function setQuorumVotes(uint256 _quorumVotes) external {
        require(msg.sender == address(this), "Only governance");
        quorumVotes = _quorumVotes;
    }
}

interface IGovernanceToken {
    function balanceOf(address account) external view returns (uint256);
}
