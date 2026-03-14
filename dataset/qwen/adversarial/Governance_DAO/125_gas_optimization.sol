// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleDAO {
    address public owner;
    uint256 public proposalCount;

    struct Proposal {
        address recipient;
        uint256 amount;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public members;

    event ProposalCreated(uint256 indexed proposalId, address recipient, uint256 amount);
    event ProposalExecuted(uint256 indexed proposalId);

    constructor() {
        owner = msg.sender;
        members[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender], "Not a member");
        _;
    }

    function addMember(address _member) external onlyOwner {
        members[_member] = true;
    }

    function createProposal(address _recipient, uint256 _amount) external onlyMember {
        proposals[proposalCount] = Proposal(_recipient, _amount, false);
        emit ProposalCreated(proposalCount, _recipient, _amount);
        proposalCount++;
    }

    function executeProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        (bool success, ) = proposal.recipient.call{value: proposal.amount}("");
        require(success, "Transfer failed");
        proposal.executed = true;
        emit ProposalExecuted(_proposalId);
    }

    receive() external payable {}
}