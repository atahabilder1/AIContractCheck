// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract SimpleDAO {
    // Reentrancy guard
    bool private _entered;

    modifier nonReentrant() {
        require(!_entered, "REENTRANCY");
        _entered = true;
        _;
        _entered = false;
    }

    // Ownership
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    // Governance
    IERC20 public immutable governanceToken;
    string public name;

    uint256 public proposalCount;
    uint256 public proposalThreshold; // minimum tokens to create a proposal
    uint256 public quorumVotes;       // minimum FOR votes required to pass
    uint256 public votingDelay;       // seconds until voting starts after proposal creation
    uint256 public votingPeriod;      // seconds voting lasts

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        string description;
        uint64 startTime;
        uint64 endTime;
        bool executed;
        bool canceled;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) private _proposals;

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed target,
        uint256 value,
        bytes data,
        string description,
        uint64 startTime,
        uint64 endTime
    );

    event VoteCast(
        uint256 indexed id,
        address indexed voter,
        uint8 support,
        uint256 weight,
        string reason
    );

    event ProposalExecuted(uint256 indexed id, bytes result);
    event ProposalCanceled(uint256 indexed id);

    constructor(
        address token_,
        string memory name_,
        uint256 proposalThreshold_,
        uint256 quorumVotes_,
        uint256 votingDelay_,   // in seconds
        uint256 votingPeriod_   // in seconds
    ) {
        require(token_ != address(0), "TOKEN_ZERO");
        require(votingPeriod_ > 0, "PERIOD_ZERO");
        require(quorumVotes_ > 0, "QUORUM_ZERO");

        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        governanceToken = IERC20(token_);
        name = name_;
        proposalThreshold = proposalThreshold_;
        quorumVotes = quorumVotes_;
        votingDelay = votingDelay_;
        votingPeriod = votingPeriod_;
    }

    // States:
    // 0 = Pending, 1 = Active, 2 = Defeated, 3 = Succeeded, 4 = Executed, 5 = Canceled
    function state(uint256 proposalId) public view returns (uint8) {
        Proposal storage p = _proposals[proposalId];

        if (p.canceled) return 5;
        if (p.executed) return 4;
        if (p.startTime == 0) return 2; // non-existing -> defeated by default
        if (block.timestamp < p.startTime) return 0;
        if (block.timestamp <= p.endTime) return 1;

        // After voting ended
        bool passed = p.forVotes >= quorumVotes && p.forVotes > p.againstVotes;
        return passed ? 3 : 2;
    }

    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external returns (uint256 id) {
        require(governanceToken.balanceOf(msg.sender) >= proposalThreshold, "THRESHOLD");
        require(target != address(0) || bytes(description).length != 0, "INVALID_PROPOSAL");

        id = ++proposalCount;
        Proposal storage p = _proposals[id];
        p.proposer = msg.sender;
        p.target = target;
        p.value = value;
        p.data = data;
        p.description = description;

        uint64 start = uint64(block.timestamp + votingDelay);
        uint64 end = uint64(start + votingPeriod);
        p.startTime = start;
        p.endTime = end;

        emit ProposalCreated(
            id,
            msg.sender,
            target,
            value,
            data,
            description,
            start,
            end
        );
    }

    // support: 0 = Against, 1 = For, 2 = Abstain
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight) {
        return castVoteWithReason(proposalId, support, "");
    }

    function castVoteWithReason(uint256 proposalId, uint8 support, string memory reason)
        public
        returns (uint256 weight)
    {
        require(support <= 2, "INVALID_SUPPORT");
        Proposal storage p = _proposals[proposalId];
        require(p.startTime != 0, "NO_PROPOSAL");
        require(state(proposalId) == 1, "NOT_ACTIVE");
        require(!p.hasVoted[msg.sender], "ALREADY_VOTED");

        p.hasVoted[msg.sender] = true;
        weight = governanceToken.balanceOf(msg.sender);

        if (support == 0) {
            p.againstVotes += weight;
        } else if (support == 1) {
            p.forVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight, reason);
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return _proposals[proposalId].hasVoted[voter];
    }

    function execute(uint256 proposalId) external payable nonReentrant returns (bytes memory result) {
        Proposal storage p = _proposals[proposalId];
        require(p.startTime != 0, "NO_PROPOSAL");
        require(state(proposalId) == 3, "NOT_SUCCEEDED");
        require(!p.executed, "ALREADY_EXECUTED");

        p.executed = true;

        if (p.target != address(0)) {
            (bool ok, bytes memory res) = p.target.call{value: p.value}(p.data);
            require(ok, "CALL_FAILED");
            emit ProposalExecuted(proposalId, res);
            return res;
        } else {
            // No-op execution (e.g., signaling-only proposal)
            emit ProposalExecuted(proposalId, bytes(""));
            return bytes("");
        }
    }

    function cancel(uint256 proposalId) external {
        Proposal storage p = _proposals[proposalId];
        require(p.startTime != 0, "NO_PROPOSAL");
        require(!p.executed, "ALREADY_EXECUTED");
        require(!p.canceled, "ALREADY_CANCELED");
        require(msg.sender == p.proposer || msg.sender == owner, "NOT_AUTHORIZED");
        require(state(proposalId) != 4, "ALREADY_EXECUTED");

        p.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    // View helper to fetch proposal core data (excluding mappings)
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            address target,
            uint256 value,
            bytes memory data,
            string memory description,
            uint64 startTime,
            uint64 endTime,
            bool executed,
            bool canceled,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes
        )
    {
        Proposal storage p = _proposals[proposalId];
        proposer = p.proposer;
        target = p.target;
        value = p.value;
        data = p.data;
        description = p.description;
        startTime = p.startTime;
        endTime = p.endTime;
        executed = p.executed;
        canceled = p.canceled;
        forVotes = p.forVotes;
        againstVotes = p.againstVotes;
        abstainVotes = p.abstainVotes;
    }

    // Admin setters
    function setProposalThreshold(uint256 newThreshold) external onlyOwner {
        proposalThreshold = newThreshold;
    }

    function setQuorumVotes(uint256 newQuorum) external onlyOwner {
        require(newQuorum > 0, "QUORUM_ZERO");
        quorumVotes = newQuorum;
    }

    function setVotingParams(uint256 newDelay, uint256 newPeriod) external onlyOwner {
        require(newPeriod > 0, "PERIOD_ZERO");
        votingDelay = newDelay;
        votingPeriod = newPeriod;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "OWNER_ZERO");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Accept ETH for proposals that require value
    receive() external payable {}
    fallback() external payable {}
}