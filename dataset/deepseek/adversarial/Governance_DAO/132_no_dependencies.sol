// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20, Ownable {
    constructor() ERC20("GovernanceToken", "GT") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract GovernanceDAO is Ownable {
    using SafeMath for uint256;

    GovernanceToken public governanceToken;
    mapping(address => bool) public voters;
    mapping(address => uint256) public voteCounts;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    struct Proposal {
        uint256 id;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        mapping(address => bool) voted;
    }

    event ProposalCreated(uint256 id, string description, uint256 yesVotes, uint256 noVotes);
    event VoteCasted(uint256 proposalId, address voter, bool vote);
    event ProposalExecuted(uint256 id, bool result);

    modifier onlyVoters() {
        require(voters[msg.sender], "Not a voter");
        _;
    }

    constructor(address _governanceToken) {
        governanceToken = GovernanceToken(_governanceToken);
    }

    function addVoter(address _voter) public onlyOwner {
        require(!voters[_voter], "Already a voter");
        voters[_voter] = true;
    }

    function createProposal(string memory description) public onlyOwner returns (uint256) {
        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.description = description;
        proposal.executed = false;
        emit ProposalCreated(proposalCount, description, 0, 0);
        return proposalCount;
    }

    function vote(uint256 proposalId, bool vote) public onlyVoters {
        require(!proposals[proposalId].voted[msg.sender], "Already voted");
        Proposal storage proposal = proposals[proposalId];
        proposal.voted[msg.sender] = true;
        if (vote) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        emit VoteCasted(proposalId, msg.sender, vote);
    }

    function executeProposal(uint256 proposalId) public onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.yesVotes > proposal.noVotes, "Not enough yes votes");
        proposal.executed = true;
        emit ProposalExecuted(proposalId, true);
    }
}