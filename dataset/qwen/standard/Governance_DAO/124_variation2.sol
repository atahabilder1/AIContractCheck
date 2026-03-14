// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigGovernance {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 voteDeadline;
        uint256 councilApprovalDeadline;
        uint256 yesVotes;
        uint256 noVotes;
        bool councilApproved;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public councilMembers;
    uint256 public proposalCount;
    uint256 public quorumPercentage;
    uint256 public councilQuorum;
    uint256 public votingDuration;
    uint256 public councilVotingDuration;
    IERC20 public governanceToken;

    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event VoteCast(uint256 indexed proposalId, address voter, bool inFavor);
    event CouncilApproval(uint256 indexed proposalId, bool approved);
    event ProposalExecuted(uint256 indexed proposalId, bool result);

    constructor(
        address _governanceToken,
        uint256 _quorumPercentage,
        uint256 _councilQuorum,
        uint256 _votingDuration,
        uint256 _councilVotingDuration
    ) {
        governanceToken = IERC20(_governanceToken);
        quorumPercentage = _quorumPercentage;
        councilQuorum = _councilQuorum;
        votingDuration = _votingDuration;
        councilVotingDuration = _councilVotingDuration;
    }

    function addCouncilMember(address _member) external {
        require(msg.sender == address(this), "Only governance can add council members");
        councilMembers[_member] = true;
    }

    function removeCouncilMember(address _member) external {
        require(msg.sender == address(this), "Only governance can remove council members");
        councilMembers[_member] = false;
    }

    function createProposal(string memory _description) external {
        uint256 id = proposalCount++;
        proposals[id] = Proposal({
            id: id,
            proposer: msg.sender,
            description: _description,
            voteDeadline: block.timestamp + votingDuration,
            councilApprovalDeadline: block.timestamp + councilVotingDuration,
            yesVotes: 0,
            noVotes: 0,
            councilApproved: false,
            executed: false
        });
        emit ProposalCreated(id, msg.sender, _description);
    }

    function castVote(uint256 _proposalId, bool _inFavor) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.voteDeadline, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(governanceToken.balanceOf(msg.sender) > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        if (_inFavor) {
            proposal.yesVotes += governanceToken.balanceOf(msg.sender);
        } else {
            proposal.noVotes += governanceToken.balanceOf(msg.sender);
        }

        emit VoteCast(_proposalId, msg.sender, _inFavor);
    }

    function councilApprove(uint256 _proposalId, bool _approved) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.councilApprovalDeadline, "Council voting period has ended");
        require(councilMembers[msg.sender], "Not a council member");
        require(!proposal.councilApproved, "Already approved");

        proposal.councilApproved = _approved;
        emit CouncilApproval(_proposalId, _approved);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Already executed");
        require(block.timestamp > proposal.voteDeadline, "Voting period has not ended");

        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;
        uint256 quorum = (governanceToken.totalSupply() * quorumPercentage) / 100;
        bool quorumMet = totalVotes >= quorum;

        if (proposal.councilApproved && quorumMet && proposal.yesVotes > proposal.noVotes) {
            proposal.executed = true;
            emit ProposalExecuted(_proposalId, true);
        } else {
            proposal.executed = true;
            emit ProposalExecuted(_proposalId, false);
        }
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}