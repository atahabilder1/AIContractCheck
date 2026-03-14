// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20, Ownable {
    constructor() ERC20("GovernanceToken", "GT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract GovernanceDAO is Ownable {
    using SafeMath for uint256;

    GovernanceToken public token;
    mapping(address => bool) public members;
    uint256 public quorum;

    event ProposalCreated(uint256 proposalId, address indexed proposer, uint256 quorum, string description);
    event ProposalExecuted(uint256 proposalId, bool success);

    struct Proposal {
        address payable target;
        uint256 amount;
        string description;
        bool executed;
        mapping(address => bool) votes;
        uint256 yesVotes;
        uint256 noVotes;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    constructor(uint256 _quorum, address _tokenAddress) {
        quorum = _quorum;
        token = GovernanceToken(_tokenAddress);
    }

    function createProposal(address payable target, uint256 amount, string memory description) public {
        require(members[msg.sender], "You are not a member");
        Proposal storage proposal = proposals[proposalCount];
        proposal.target = target;
        proposal.amount = amount;
        proposal.description = description;
        proposal.executed = false;
        proposalCount++;
        emit ProposalCreated(proposalCount - 1, msg.sender, quorum, description);
    }

    function vote(uint256 proposalId, bool vote) public {
        require(members[msg.sender], "You are not a member");
        require(proposalId < proposalCount, "Proposal does not exist");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.votes[msg.sender], "You have already voted");
        proposal.votes[msg.sender] = vote;
        if (vote) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
    }

    function executeProposal(uint256 proposalId) public {
        require(proposalId < proposalCount, "Proposal does not exist");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.yesVotes >= quorum, "Not enough yes votes");
        proposal.executed = true;
        (bool success, ) = proposal.target.call{value: proposal.amount}("");
        require(success, "Transfer failed");
        emit ProposalExecuted(proposalId, success);
    }

    function addMember(address member) public onlyOwner {
        members[member] = true;
    }

    function removeMember(address member) public onlyOwner {
        members[member] = false;
    }

    function setQuorum(uint256 _quorum) public onlyOwner {
        quorum = _quorum;
    }
}