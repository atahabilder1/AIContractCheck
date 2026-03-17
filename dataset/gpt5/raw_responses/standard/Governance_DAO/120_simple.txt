// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address holder, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract BasicDAOVoting {
    struct Proposal {
        address proposer;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool exists;
    }

    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 weight;
    }

    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated
    }

    IERC20 public immutable token;

    uint256 public immutable votingPeriod;       // in seconds
    uint256 public immutable quorumVotes;        // minimum total votes (for + against) required
    uint256 public immutable proposalThreshold;  // minimum staked tokens to create a proposal

    uint256 public proposalCount;
    uint256 public totalStaked;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lockedUntil;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed id, address indexed proposer, string description, uint256 startTime, uint256 endTime);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);

    constructor(
        address _token,
        uint256 _votingPeriod,
        uint256 _quorumVotes,
        uint256 _proposalThreshold
    ) {
        require(_token != address(0), "Invalid token");
        require(_votingPeriod > 0, "Voting period must be > 0");
        token = IERC20(_token);
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
        proposalThreshold = _proposalThreshold;
    }

    // Stake tokens to gain voting power
    function stake(uint256 amount) external {
        require(amount > 0, "Amount = 0");
        // Pull tokens in first
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    // Unstake tokens if not locked by active votes
    function unstake(uint256 amount) external {
        require(amount > 0, "Amount = 0");
        require(block.timestamp >= lockedUntil[msg.sender], "Tokens are locked");
        uint256 balance = stakedBalance[msg.sender];
        require(amount <= balance, "Insufficient staked");

        // Effects
        stakedBalance[msg.sender] = balance - amount;
        totalStaked -= amount;

        // Interactions
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    // Create a new proposal
    function propose(string calldata description) external returns (uint256) {
        require(stakedBalance[msg.sender] >= proposalThreshold, "Insufficient stake to propose");

        uint256 id = ++proposalCount;
        uint256 start = block.timestamp;
        uint256 end = start + votingPeriod;

        proposals[id] = Proposal({
            proposer: msg.sender,
            description: description,
            startTime: start,
            endTime: end,
            forVotes: 0,
            againstVotes: 0,
            exists: true
        });

        emit ProposalCreated(id, msg.sender, description, start, end);
        return id;
    }

    // Cast a vote on a proposal
    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(p.exists, "Unknown proposal");
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp <= p.endTime, "Voting ended");

        Receipt storage r = receipts[proposalId][msg.sender];
        require(!r.hasVoted, "Already voted");

        uint256 weight = stakedBalance[msg.sender];
        require(weight > 0, "No voting power");

        r.hasVoted = true;
        r.support = support;
        r.weight = weight;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        // Lock tokens until proposal ends
        if (lockedUntil[msg.sender] < p.endTime) {
            lockedUntil[msg.sender] = p.endTime;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    // Read the state of a proposal
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal memory p = proposals[proposalId];
        require(p.exists, "Unknown proposal");

        if (block.timestamp < p.startTime) {
            return ProposalState.Pending;
        }
        if (block.timestamp <= p.endTime) {
            return ProposalState.Active;
        }

        bool hasQuorum = (p.forVotes + p.againstVotes) >= quorumVotes;
        bool passed = p.forVotes > p.againstVotes;

        if (hasQuorum && passed) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    // Helper getters
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            uint256 forVotes,
            uint256 againstVotes,
            ProposalState currentState
        )
    {
        Proposal memory p = proposals[proposalId];
        require(p.exists, "Unknown proposal");
        proposer = p.proposer;
        description = p.description;
        startTime = p.startTime;
        endTime = p.endTime;
        forVotes = p.forVotes;
        againstVotes = p.againstVotes;
        currentState = state(proposalId);
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (bool hasVoted, bool support, uint256 weight) {
        Receipt memory r = receipts[proposalId][voter];
        hasVoted = r.hasVoted;
        support = r.support;
        weight = r.weight;
    }
}