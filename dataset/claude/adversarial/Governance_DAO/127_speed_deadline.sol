// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovernanceDAO {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    address public owner;
    uint256 public proposalCount;
    uint256 public votingPeriod = 3 days;
    uint256 public quorum = 1;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => bool) public members;
    uint256 public memberCount;

    event ProposalCreated(uint256 indexed id, address proposer, string description);
    event Voted(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);
    event MemberAdded(address member, uint256 votingPower);
    event MemberRemoved(address member);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender], "Not a member");
        _;
    }

    constructor() {
        owner = msg.sender;
        members[msg.sender] = true;
        votingPower[msg.sender] = 1;
        memberCount = 1;
    }

    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(!members[_member], "Already a member");
        require(_votingPower > 0, "Power must be > 0");
        members[_member] = true;
        votingPower[_member] = _votingPower;
        memberCount++;
        emit MemberAdded(_member, _votingPower);
    }

    function removeMember(address _member) external onlyOwner {
        require(members[_member], "Not a member");
        require(_member != owner, "Cannot remove owner");
        members[_member] = false;
        votingPower[_member] = 0;
        memberCount--;
        emit MemberRemoved(_member);
    }

    function createProposal(string calldata _description) external onlyMember returns (uint256) {
        uint256 id = proposalCount++;
        Proposal storage p = proposals[id];
        p.id = id;
        p.proposer = msg.sender;
        p.description = _description;
        p.deadline = block.timestamp + votingPeriod;
        emit ProposalCreated(id, msg.sender, _description);
        return id;
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp < p.deadline, "Voting ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        require(!p.executed, "Already executed");

        p.hasVoted[msg.sender] = true;
        uint256 weight = votingPower[msg.sender];

        if (_support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit Voted(_proposalId, msg.sender, _support, weight);
    }

    function executeProposal(uint256 _proposalId) external onlyMember {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp >= p.deadline, "Voting not ended");
        require(!p.executed, "Already executed");
        require(p.forVotes > p.againstVotes, "Proposal not passed");
        require(p.forVotes >= quorum, "Quorum not reached");

        p.executed = true;
        emit ProposalExecuted(_proposalId);
    }

    function setVotingPeriod(uint256 _period) external onlyOwner {
        votingPeriod = _period;
    }

    function setQuorum(uint256 _quorum) external onlyOwner {
        quorum = _quorum;
    }

    function getProposal(uint256 _proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 deadline,
        bool executed
    ) {
        Proposal storage p = proposals[_proposalId];
        return (p.proposer, p.description, p.forVotes, p.againstVotes, p.deadline, p.executed);
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    receive() external payable {}
}