// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract QuadraticVotingDAO is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterTokensAtSnapshot;
    }

    IERC20 public immutable governanceToken;
    uint256 public proposalCounter;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000 * 10**18; // 1000 tokens
    uint256 public constant QUORUM_PERCENTAGE = 10; // 10% of total supply

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public lastProposalTime;
    
    uint256 public constant PROPOSAL_COOLDOWN = 1 days;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 votingPower,
        uint256 tokensHeld
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCounter, "Invalid proposal ID");
        _;
    }

    modifier onlyDuringVoting(uint256 proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.executed && !proposal.canceled, "Proposal not active");
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }

    function createProposal(string calldata description) external nonReentrant returns (uint256) {
        require(bytes(description).length > 0, "Empty description");
        require(bytes(description).length <= 1000, "Description too long");
        require(
            governanceToken.balanceOf(msg.sender) >= MIN_PROPOSAL_THRESHOLD,
            "Insufficient tokens to propose"
        );
        require(
            block.timestamp >= lastProposalTime[msg.sender] + PROPOSAL_COOLDOWN,
            "Proposal cooldown active"
        );

        proposalCounter++;
        uint256 proposalId = proposalCounter;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;

        lastProposalTime[msg.sender] = block.timestamp;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            newProposal.startTime,
            newProposal.endTime
        );

        return proposalId;
    }

    function vote(uint256 proposalId, bool support) 
        external 
        validProposal(proposalId) 
        onlyDuringVoting(proposalId)
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 tokensHeld = governanceToken.balanceOf(msg.sender);
        require(tokensHeld > 0, "No tokens to vote");

        // Calculate quadratic voting power: square root of tokens held
        uint256 votingPower = tokensHeld.sqrt();
        require(votingPower > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voterTokensAtSnapshot[msg.sender] = tokensHeld;

        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        emit VoteCast(msg.sender, proposalId, support, votingPower, tokensHeld);
    }

    function executeProposal(uint256 proposalId) 
        external 
        validProposal(proposalId) 
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorumRequired = (totalSupply * QUORUM_PERCENTAGE) / 100;
        
        // For quadratic voting, we need to adjust quorum calculation
        // Using square root of required quorum for fairness
        uint256 adjustedQuorum = quorumRequired.sqrt();
        
        require(totalVotes >= adjustedQuorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) 
        external 
        validProposal(proposalId) 
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized to cancel"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function getProposalInfo(uint256 proposalId) 
        external 
        view 
        validProposal(proposalId) 
        returns (
            uint256 id,
            address proposer,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            bool canceled
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.canceled
        );
    }

    function hasVoted(uint256 proposalId, address voter) 
        external 
        view 
        validProposal(proposalId) 
        returns (bool) 
    {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVotingPower(address voter) external view returns (uint256) {
        uint256 tokens = governanceToken.balanceOf(voter);
        return tokens.sqrt();
    }

    function getProposalState(uint256 proposalId) 
        external 
        view 
        validProposal(proposalId) 
        returns (string memory) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) return "Canceled";
        if (proposal.executed) return "Executed";
        if (block.timestamp < proposal.startTime) return "Pending";
        if (block.timestamp <= proposal.endTime) return "Active";
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 adjustedQuorum = ((totalSupply * QUORUM_PERCENTAGE) / 100).sqrt();
        
        if (totalVotes < adjustedQuorum) return "Failed (Quorum)";
        if (proposal.forVotes <= proposal.againstVotes) return "Defeated";
        
        return "Succeeded";
    }
}