// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface IERC20Snapshot is IERC20 {
    function snapshot() external returns (uint256);
    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);
}

contract QuadraticVotingDAO {
    struct Proposal {
        string description;
        uint256 snapshotId;
        uint64 startTime;
        uint64 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
    }

    IERC20Snapshot public immutable token;

    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public voteWeight;

    event ProposalCreated(uint256 indexed proposalId, string description, uint256 snapshotId, uint64 startTime, uint64 endTime);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event Executed(uint256 indexed proposalId, bool success);

    constructor(IERC20Snapshot _token) {
        token = _token;
    }

    function propose(string calldata description, uint64 votingPeriod) external returns (uint256 proposalId) {
        require(votingPeriod > 0, "invalid voting period");

        uint256 snapshotId = token.snapshot();
        uint64 startTime = uint64(block.timestamp);
        uint64 endTime = startTime + votingPeriod;

        proposalId = ++proposalCount;

        proposals[proposalId] = Proposal({
            description: description,
            snapshotId: snapshotId,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        });

        emit ProposalCreated(proposalId, description, snapshotId, startTime, endTime);
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(p.snapshotId != 0, "proposal not found");
        require(block.timestamp >= p.startTime, "voting not started");
        require(block.timestamp <= p.endTime, "voting ended");
        require(!hasVoted[proposalId][msg.sender], "already voted");

        uint256 bal = token.balanceOfAt(msg.sender, p.snapshotId);
        uint256 weight = _sqrt(bal);
        require(weight > 0, "no voting power");

        hasVoted[proposalId][msg.sender] = true;
        voteWeight[proposalId][msg.sender] = weight;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.snapshotId != 0, "proposal not found");
        require(block.timestamp > p.endTime, "voting not ended");
        require(!p.executed, "already executed");

        bool success = p.forVotes > p.againstVotes;
        p.executed = true;

        emit Executed(proposalId, success);
    }

    function getVotingPower(uint256 proposalId, address voter) external view returns (uint256) {
        Proposal storage p = proposals[proposalId];
        if (p.snapshotId == 0) return 0;
        return _sqrt(token.balanceOfAt(voter, p.snapshotId));
    }

    function proposalState(uint256 proposalId) external view returns (string memory) {
        Proposal storage p = proposals[proposalId];
        if (p.snapshotId == 0) return "Nonexistent";
        if (block.timestamp < p.startTime) return "Pending";
        if (block.timestamp <= p.endTime) return "Active";
        if (!p.executed) return "SucceededOrDefeated";
        return "Executed";
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) >> 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) >> 1;
        }
    }
}