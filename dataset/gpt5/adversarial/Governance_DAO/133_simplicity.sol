// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MinimalDAO {
    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
    }

    uint256 public proposalCount;
    uint256 public votingPeriod; // in blocks
    uint256 public quorum;       // minimum forVotes required

    mapping(address => bool) public isMember;
    uint256 public memberCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event MemberJoined(address indexed account);
    event MemberLeft(address indexed account);
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed target,
        uint256 value,
        uint256 startBlock,
        uint256 endBlock,
        bytes data,
        string description
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed id, address indexed executor);

    modifier onlyMember() {
        require(isMember[msg.sender], "Not a member");
        _;
    }

    constructor(uint256 _votingPeriod, uint256 _quorum) {
        require(_votingPeriod > 0, "Invalid voting period");
        votingPeriod = _votingPeriod;
        quorum = _quorum;
        // Optional: deployer joins as first member
        isMember[msg.sender] = true;
        memberCount = 1;
        emit MemberJoined(msg.sender);
    }

    receive() external payable {}
    fallback() external payable {}

    function join() external {
        require(!isMember[msg.sender], "Already a member");
        isMember[msg.sender] = true;
        memberCount += 1;
        emit MemberJoined(msg.sender);
    }

    function leave() external {
        require(isMember[msg.sender], "Not a member");
        isMember[msg.sender] = false;
        memberCount -= 1;
        emit MemberLeft(msg.sender);
    }

    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external onlyMember returns (uint256 id) {
        require(target != address(0), "Invalid target");
        id = ++proposalCount;

        proposals[id] = Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            data: data,
            startBlock: block.number,
            endBlock: block.number + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        });

        emit ProposalCreated(
            id,
            msg.sender,
            target,
            value,
            block.number,
            block.number + votingPeriod,
            data,
            description
        );
    }

    function vote(uint256 proposalId, bool support) external onlyMember {
        Proposal storage p = proposals[proposalId];
        require(p.startBlock != 0, "Proposal does not exist");
        require(block.number >= p.startBlock, "Voting not started");
        require(block.number <= p.endBlock, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            p.forVotes += 1;
        } else {
            p.againstVotes += 1;
        }

        emit VoteCast(msg.sender, proposalId, support);
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.startBlock != 0, "Proposal does not exist");
        require(block.number > p.endBlock, "Voting not ended");
        require(!p.executed, "Already executed");
        require(p.forVotes > p.againstVotes, "Not passed");
        require(p.forVotes >= quorum, "Quorum not met");

        p.executed = true;

        (bool ok, ) = p.target.call{value: p.value}(p.data);
        require(ok, "Call failed");

        emit ProposalExecuted(proposalId, msg.sender);
    }
}