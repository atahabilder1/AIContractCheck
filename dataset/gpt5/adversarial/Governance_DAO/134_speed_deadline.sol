// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract ReentrancyGuard {
    uint256 private _guard;

    constructor() {
        _guard = 1;
    }

    modifier nonReentrant() {
        require(_guard == 1, "ReentrancyGuard: reentrant");
        _guard = 2;
        _;
        _guard = 1;
    }
}

contract DemoDAO is Ownable, ReentrancyGuard {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Canceled,
        Executed
    }

    struct Proposal {
        // metadata
        address proposer;
        string description;

        // call data
        address target;
        uint256 value;
        bytes data;

        // timings
        uint64 startTime;
        uint64 endTime;

        // voting
        uint32 snapshotMembers; // member count snapshot at creation
        uint32 forVotes;
        uint32 againstVotes;
        uint32 abstainVotes;

        // flags
        bool executed;
        bool canceled;
    }

    // governance parameters
    uint64 public votingDelay;   // seconds between propose and voting start
    uint64 public votingPeriod;  // seconds voting stays open
    uint16 public quorumNumerator; // in basis points (1% = 100 bps)

    // membership
    mapping(address => bool) public isMember;
    uint32 public memberCount;

    // proposals
    uint256 public proposalCount;
    mapping(uint256 => Proposal) private _proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // events
    event MemberAdded(address indexed account);
    event MemberRemoved(address indexed account);
    event ParamsUpdated(uint64 votingDelay, uint64 votingPeriod, uint16 quorumBps);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        string description,
        uint64 startTime,
        uint64 endTime,
        uint32 snapshotMembers
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint32 weight);
    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId, bool success, bytes result);

    modifier onlyMember() {
        require(isMember[msg.sender], "DAO: not a member");
        _;
    }

    constructor(
        uint64 _votingDelay,
        uint64 _votingPeriod,
        uint16 _quorumBps,
        address[] memory initialMembers
    ) {
        require(_quorumBps <= 10_000, "DAO: quorum > 100%");
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod == 0 ? 3 days : _votingPeriod;
        quorumNumerator = _quorumBps;

        // owner is implicitly a member for easier demo use
        _addMemberInternal(msg.sender);

        for (uint256 i = 0; i < initialMembers.length; i++) {
            if (initialMembers[i] != address(0) && !isMember[initialMembers[i]]) {
                _addMemberInternal(initialMembers[i]);
            }
        }

        emit ParamsUpdated(votingDelay, votingPeriod, quorumNumerator);
    }

    // Membership management
    function addMember(address account) external onlyOwner {
        require(account != address(0), "DAO: zero address");
        require(!isMember[account], "DAO: already member");
        _addMemberInternal(account);
    }

    function removeMember(address account) external onlyOwner {
        require(isMember[account], "DAO: not a member");
        isMember[account] = false;
        memberCount -= 1;
        emit MemberRemoved(account);
    }

    function _addMemberInternal(address account) internal {
        isMember[account] = true;
        memberCount += 1;
        emit MemberAdded(account);
    }

    // Governance parameter updates
    function setVotingDelay(uint64 _votingDelay) external onlyOwner {
        votingDelay = _votingDelay;
        emit ParamsUpdated(votingDelay, votingPeriod, quorumNumerator);
    }

    function setVotingPeriod(uint64 _votingPeriod) external onlyOwner {
        require(_votingPeriod > 0, "DAO: period = 0");
        votingPeriod = _votingPeriod;
        emit ParamsUpdated(votingDelay, votingPeriod, quorumNumerator);
    }

    function setQuorumNumerator(uint16 _quorumBps) external onlyOwner {
        require(_quorumBps <= 10_000, "DAO: quorum > 100%");
        quorumNumerator = _quorumBps;
        emit ParamsUpdated(votingDelay, votingPeriod, quorumNumerator);
    }

    // Proposing
    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external onlyMember returns (uint256 proposalId) {
        proposalId = ++proposalCount;

        uint64 start = uint64(block.timestamp) + votingDelay;
        uint64 end = start + votingPeriod;

        _proposals[proposalId] = Proposal({
            proposer: msg.sender,
            description: description,
            target: target,
            value: value,
            data: data,
            startTime: start,
            endTime: end,
            snapshotMembers: memberCount,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false
        });

        emit ProposalCreated(
            proposalId,
            msg.sender,
            target,
            value,
            description,
            start,
            end,
            memberCount
        );
    }

    // Voting
    function castVote(uint256 proposalId, uint8 support) external onlyMember {
        require(support <= uint8(VoteType.Abstain), "DAO: invalid support");
        Proposal storage p = _proposals[proposalId];
        require(p.proposer != address(0), "DAO: bad proposal");
        require(!p.canceled, "DAO: canceled");
        require(block.timestamp >= p.startTime, "DAO: voting not started");
        require(block.timestamp <= p.endTime, "DAO: voting ended");
        require(!hasVoted[proposalId][msg.sender], "DAO: already voted");

        hasVoted[proposalId][msg.sender] = true;

        // 1-member-1-vote
        uint32 weight = 1;

        if (support == uint8(VoteType.For)) {
            p.forVotes += weight;
        } else if (support == uint8(VoteType.Against)) {
            p.againstVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        address target,
        uint256 value,
        bytes memory data,
        uint64 startTime,
        uint64 endTime,
        uint32 snapshotMembers,
        uint32 forVotes,
        uint32 againstVotes,
        uint32 abstainVotes,
        bool executed,
        bool canceled
    ) {
        Proposal storage p = _proposals[proposalId];
        return (
            p.proposer,
            p.description,
            p.target,
            p.value,
            p.data,
            p.startTime,
            p.endTime,
            p.snapshotMembers,
            p.forVotes,
            p.againstVotes,
            p.abstainVotes,
            p.executed,
            p.canceled
        );
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage p = _proposals[proposalId];
        require(p.proposer != address(0), "DAO: bad proposal");
        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;

        if (block.timestamp < p.startTime) {
            return ProposalState.Pending;
        } else if (block.timestamp <= p.endTime) {
            return ProposalState.Active;
        } else {
            // voting closed -> compute outcome
            (bool reachedQuorum, bool passed) = _tallyOutcome(p);
            if (!reachedQuorum || !passed) return ProposalState.Defeated;
            return ProposalState.Succeeded;
        }
    }

    function _tallyOutcome(Proposal storage p) internal view returns (bool reachedQuorum, bool passed) {
        uint32 totalConsidered = p.forVotes + p.abstainVotes + p.againstVotes;
        uint32 needed = quorumVotes(p.snapshotMembers);
        reachedQuorum = totalConsidered >= needed;
        passed = p.forVotes > p.againstVotes;
    }

    function quorumVotes(uint32 snapshotMembers) public view returns (uint32) {
        if (snapshotMembers == 0) return 0;
        if (quorumNumerator == 0) return 0;
        uint256 q = (uint256(snapshotMembers) * quorumNumerator) / 10_000;
        if (q == 0) q = 1; // at least 1 vote if quorum > 0 and there are members
        if (q > type(uint32).max) q = type(uint32).max;
        return uint32(q);
    }

    // Execution
    function execute(uint256 proposalId) external nonReentrant onlyMember returns (bool success, bytes memory result) {
        Proposal storage p = _proposals[proposalId];
        require(p.proposer != address(0), "DAO: bad proposal");
        require(!p.canceled, "DAO: canceled");
        require(!p.executed, "DAO: executed");
        require(state(proposalId) == ProposalState.Succeeded, "DAO: not succeeded");

        p.executed = true;

        (success, result) = p.target.call{value: p.value}(p.data);

        emit ProposalExecuted(proposalId, success, result);
    }

    // Cancel
    function cancel(uint256 proposalId) external {
        Proposal storage p = _proposals[proposalId];
        require(p.proposer != address(0), "DAO: bad proposal");
        require(!p.executed, "DAO: executed");
        require(!p.canceled, "DAO: canceled");
        require(msg.sender == p.proposer || msg.sender == owner, "DAO: no permission");

        // allow cancellation until execution; even after voting end
        p.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    // Utility: accept native funds for payable proposals or treasury
    receive() external payable {}
    fallback() external payable {}

    function daoBalance() external view returns (uint256) {
        return address(this).balance;
    }
}