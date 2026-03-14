// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GovernanceToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("GovToken", "GOV") {
        _mint(msg.sender, initialSupply);
    }
}

contract QuadraticVotingDAO {
    IERC20 public governanceToken;
    uint256 public proposalCount;
    uint256 public votingPeriod;
    uint256 public quorum;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        address target;
        bytes callData;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string description, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 quadraticWeight);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCanceled(uint256 indexed id);

    modifier onlyTokenHolder() {
        require(governanceToken.balanceOf(msg.sender) > 0, "Must hold governance tokens");
        _;
    }

    constructor(address _token, uint256 _votingPeriod, uint256 _quorum) {
        governanceToken = IERC20(_token);
        votingPeriod = _votingPeriod;
        quorum = _quorum;
    }

    function createProposal(
        string calldata _description,
        address _target,
        bytes calldata _callData
    ) external onlyTokenHolder returns (uint256) {
        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.description = _description;
        p.target = _target;
        p.callData = _callData;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalCount, msg.sender, _description, p.endTime);
        return proposalCount;
    }

    function vote(uint256 _proposalId, bool _support) external onlyTokenHolder {
        Proposal storage p = proposals[_proposalId];
        require(p.id != 0, "Proposal does not exist");
        require(block.timestamp <= p.endTime, "Voting period ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        require(!p.canceled, "Proposal canceled");

        uint256 balance = governanceToken.balanceOf(msg.sender);
        uint256 quadraticWeight = sqrt(balance);
        require(quadraticWeight > 0, "Insufficient voting power");

        p.hasVoted[msg.sender] = true;

        if (_support) {
            p.votesFor += quadraticWeight;
        } else {
            p.votesAgainst += quadraticWeight;
        }

        emit Voted(_proposalId, msg.sender, _support, quadraticWeight);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(p.id != 0, "Proposal does not exist");
        require(block.timestamp > p.endTime, "Voting period not ended");
        require(!p.executed, "Already executed");
        require(!p.canceled, "Proposal canceled");
        require(p.votesFor + p.votesAgainst >= quorum, "Quorum not reached");
        require(p.votesFor > p.votesAgainst, "Proposal did not pass");

        p.executed = true;

        if (p.target != address(0)) {
            (bool success, ) = p.target.call(p.callData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(_proposalId);
    }

    function cancelProposal(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(p.proposer == msg.sender, "Only proposer can cancel");
        require(!p.executed, "Already executed");
        require(!p.canceled, "Already canceled");

        p.canceled = true;
        emit ProposalCanceled(_proposalId);
    }

    function getVotingPower(address _voter) external view returns (uint256) {
        return sqrt(governanceToken.balanceOf(_voter));
    }

    function getProposalVotes(uint256 _proposalId) external view returns (uint256 votesFor, uint256 votesAgainst) {
        Proposal storage p = proposals[_proposalId];
        return (p.votesFor, p.votesAgainst);
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}