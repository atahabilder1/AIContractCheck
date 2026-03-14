// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovernanceDAO {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    address public admin;
    bool public paused;
    uint256 public proposalCount;
    uint256 public votingDuration = 3 days;
    uint256 public quorumPercentage = 50;
    uint256 public memberCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public members;
    mapping(address => uint256) public memberStake;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed id);
    event MemberJoined(address indexed member, uint256 stake);
    event MemberLeft(address indexed member, uint256 stake);
    event EmergencyWithdrawal(address indexed admin, uint256 amount);
    event Paused(address indexed admin);
    event Unpaused(address indexed admin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender], "Not a member");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function join() external payable whenNotPaused {
        require(!members[msg.sender], "Already a member");
        require(msg.value >= 0.01 ether, "Minimum stake required");

        members[msg.sender] = true;
        memberStake[msg.sender] = msg.value;
        memberCount++;

        emit MemberJoined(msg.sender, msg.value);
    }

    function leave() external onlyMember whenNotPaused {
        uint256 stake = memberStake[msg.sender];
        members[msg.sender] = false;
        memberStake[msg.sender] = 0;
        memberCount--;

        (bool sent, ) = msg.sender.call{value: stake}("");
        require(sent, "Transfer failed");

        emit MemberLeft(msg.sender, stake);
    }

    function createProposal(string calldata _description) external onlyMember whenNotPaused returns (uint256) {
        uint256 proposalId = proposalCount++;
        Proposal storage p = proposals[proposalId];
        p.id = proposalId;
        p.proposer = msg.sender;
        p.description = _description;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + votingDuration;

        emit ProposalCreated(proposalId, msg.sender, _description);
        return proposalId;
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember whenNotPaused {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp <= p.endTime, "Voting ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        require(!p.executed, "Already executed");

        p.hasVoted[msg.sender] = true;
        uint256 weight = memberStake[msg.sender];

        if (_support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit Voted(_proposalId, msg.sender, _support);
    }

    function executeProposal(uint256 _proposalId) external onlyMember whenNotPaused {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp > p.endTime, "Voting not ended");
        require(!p.executed, "Already executed");

        uint256 totalVotes = p.forVotes + p.againstVotes;
        uint256 totalStake = address(this).balance;
        require(totalVotes * 100 >= totalStake * quorumPercentage, "Quorum not reached");
        require(p.forVotes > p.againstVotes, "Proposal rejected");

        p.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    // --- Emergency Admin Functions ---

    function emergencyPause() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    function emergencyUnpause() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        (bool sent, ) = admin.call{value: balance}("");
        require(sent, "Transfer failed");

        emit EmergencyWithdrawal(admin, balance);
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Zero address");
        admin = _newAdmin;
    }

    function setVotingDuration(uint256 _duration) external onlyAdmin {
        votingDuration = _duration;
    }

    function setQuorumPercentage(uint256 _percentage) external onlyAdmin {
        require(_percentage <= 100, "Invalid percentage");
        quorumPercentage = _percentage;
    }

    receive() external payable {}
}