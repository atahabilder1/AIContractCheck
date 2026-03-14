// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract QuadraticVotingDAO {
    using SafeMath for uint256;

    IERC20 public governanceToken;
    uint256 public proposalCount;

    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        mapping(address => uint256) votes;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public lastVotedProposal;

    event ProposalCreated(uint256 id, string description);
    event Voted(uint256 proposalId, address voter, uint256 votes);
    event ProposalExecuted(uint256 id);

    constructor(address _governanceToken) {
        governanceToken = IERC20(_governanceToken);
    }

    function createProposal(string memory _description) public {
        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.description = _description;
        proposal.voteCount = 0;
        proposal.executed = false;

        emit ProposalCreated(proposalCount, _description);
    }

    function vote(uint256 _proposalId, uint256 _tokenAmount) public {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        require(lastVotedProposal[msg.sender] != _proposalId, "Already voted on this proposal");

        uint256 balance = governanceToken.balanceOf(msg.sender);
        require(balance >= _tokenAmount, "Insufficient token balance");

        uint256 votes = sqrt(_tokenAmount);
        require(votes > 0, "Invalid vote count");

        governanceToken.transferFrom(msg.sender, address(this), _tokenAmount);

        Proposal storage proposal = proposals[_proposalId];
        proposal.votes[msg.sender] = proposal.votes[msg.sender].add(votes);
        proposal.voteCount = proposal.voteCount.add(votes);

        lastVotedProposal[msg.sender] = _proposalId;

        emit Voted(_proposalId, msg.sender, votes);
    }

    function executeProposal(uint256 _proposalId) public {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");

        // Add custom logic for proposal execution
        // require(proposal.voteCount > someThreshold, "Not enough votes");

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}