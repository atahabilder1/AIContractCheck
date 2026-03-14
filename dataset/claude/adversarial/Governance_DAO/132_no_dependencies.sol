// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
        bool canceled;
        mapping(address => bool) hasVoted;
        bytes[] calldatas;
        address[] targets;
        uint256[] values;
    }

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Executed
    }

    address public owner;
    uint256 public proposalCount;
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public quorum;
    uint256 public proposalThreshold;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => address) public delegates;
    mapping(address => uint256) public memberSince;

    uint256 public totalVotingPower;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);
    event DelegateChanged(address indexed delegator, address indexed toDelegate);
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMember() {
        require(votingPower[msg.sender] > 0 || votingPower[delegates[msg.sender]] > 0, "Not a member");
        _;
    }

    constructor(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _quorum,
        uint256 _proposalThreshold
    ) {
        owner = msg.sender;
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        quorum = _quorum;
        proposalThreshold = _proposalThreshold;

        votingPower[msg.sender] = 1;
        totalVotingPower = 1;
        memberSince[msg.sender] = block.timestamp;
    }

    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(_member != address(0), "Zero address");
        require(votingPower[_member] == 0, "Already a member");
        require(_votingPower > 0, "Power must be > 0");

        votingPower[_member] = _votingPower;
        totalVotingPower += _votingPower;
        memberSince[_member] = block.timestamp;

        emit MemberAdded(_member, _votingPower);
    }

    function removeMember(address _member) external onlyOwner {
        require(_member != owner, "Cannot remove owner");
        require(votingPower[_member] > 0, "Not a member");

        totalVotingPower -= votingPower[_member];
        votingPower[_member] = 0;
        memberSince[_member] = 0;

        emit MemberRemoved(_member);
    }

    function delegate(address _to) external {
        require(votingPower[msg.sender] > 0, "No voting power");
        require(_to != msg.sender, "Cannot self-delegate");
        delegates[msg.sender] = _to;
        emit DelegateChanged(msg.sender, _to);
    }

    function getEffectiveVotingPower(address _voter) public view returns (uint256) {
        uint256 power = votingPower[_voter];
        return power;
    }

    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external onlyMember returns (uint256) {
        require(
            getEffectiveVotingPower(msg.sender) >= proposalThreshold,
            "Below proposal threshold"
        );
        require(_targets.length == _values.length && _targets.length == _calldatas.length, "Length mismatch");
        require(_targets.length > 0, "Empty proposal");

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.description = _description;
        p.startTime = block.timestamp + votingDelay;
        p.endTime = block.timestamp + votingDelay + votingPeriod;

        for (uint256 i = 0; i < _targets.length; i++) {
            p.targets.push(_targets[i]);
            p.values.push(_values[i]);
            p.calldatas.push(_calldatas[i]);
        }

        emit ProposalCreated(proposalCount, msg.sender, _description);
        return proposalCount;
    }

    function state(uint256 _proposalId) public view returns (ProposalState) {
        Proposal storage p = proposals[_proposalId];
        require(p.id != 0, "Proposal does not exist");

        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (block.timestamp < p.startTime) return ProposalState.Pending;
        if (block.timestamp <= p.endTime) return ProposalState.Active;

        if (p.forVotes > p.againstVotes && (p.forVotes + p.againstVotes) >= quorum) {
            return ProposalState.Succeeded;
        }
        return ProposalState.Defeated;
    }

    function castVote(uint256 _proposalId, bool _support) external onlyMember {
        Proposal storage p = proposals[_proposalId];
        require(state(_proposalId) == ProposalState.Active, "Voting not active");
        require(!p.hasVoted[msg.sender], "Already voted");

        uint256 weight = getEffectiveVotingPower(msg.sender);
        require(weight > 0, "No voting power");

        p.hasVoted[msg.sender] = true;

        if (_support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit VoteCast(_proposalId, msg.sender, _support, weight);
    }

    function execute(uint256 _proposalId) external {
        require(state(_proposalId) == ProposalState.Succeeded, "Not succeeded");

        Proposal storage p = proposals[_proposalId];
        p.executed = true;

        for (uint256 i = 0; i < p.targets.length; i++) {
            (bool success, ) = p.targets[i].call{value: p.values[i]}(p.calldatas[i]);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(_proposalId);
    }

    function cancel(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(
            msg.sender == p.proposer || msg.sender == owner,
            "Not authorized"
        );
        require(!p.executed, "Already executed");
        require(!p.canceled, "Already canceled");

        p.canceled = true;
        emit ProposalCanceled(_proposalId);
    }

    function setQuorum(uint256 _newQuorum) external onlyOwner {
        uint256 old = quorum;
        quorum = _newQuorum;
        emit QuorumUpdated(old, _newQuorum);
    }

    function setVotingDelay(uint256 _votingDelay) external onlyOwner {
        votingDelay = _votingDelay;
    }

    function setVotingPeriod(uint256 _votingPeriod) external onlyOwner {
        votingPeriod = _votingPeriod;
    }

    function setProposalThreshold(uint256 _threshold) external onlyOwner {
        proposalThreshold = _threshold;
    }

    function getProposalVotes(uint256 _proposalId) external view returns (uint256 forVotes, uint256 againstVotes) {
        Proposal storage p = proposals[_proposalId];
        return (p.forVotes, p.againstVotes);
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Zero address");
        owner = _newOwner;
    }

    receive() external payable {}
}