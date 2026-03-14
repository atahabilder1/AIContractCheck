// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiSigGovernance is Ownable {
    IERC20 public token;
    address[] public delegates;
    uint256 public quorum;

    struct Proposal {
        address recipient;
        uint256 amount;
        string description;
        bool executed;
        mapping(address => bool) votes;
        uint256 voteCount;
    }

    Proposal[] public proposals;

    event ProposalCreated(uint256 indexed proposalId, address indexed recipient, uint256 amount, string description);
    event ProposalExecuted(uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId, address indexed voter, bool approval);

    constructor(address _token, address[] memory _delegates, uint256 _quorum) {
        token = IERC20(_token);
        delegates = _delegates;
        quorum = _quorum;
    }

    function createProposal(address _recipient, uint256 _amount, string memory _description) public {
        require(token.balanceOf(msg.sender) >= quorum, "Not enough tokens to create a proposal");
        Proposal storage p = proposals.push();
        p.recipient = _recipient;
        p.amount = _amount;
        p.description = _description;
        p.executed = false;
        p.voteCount = 0;
        emit ProposalCreated(proposals.length - 1, _recipient, _amount, _description);
    }

    function vote(uint256 proposalId, bool approval) public {
        require(isValidDelegate(msg.sender), "Only delegates can vote");
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Proposal already executed");
        require(!p.votes[msg.sender], "Already voted");
        p.votes[msg.sender] = approval;
        p.voteCount++;
        emit Voted(proposalId, msg.sender, approval);
    }

    function executeProposal(uint256 proposalId) public {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Proposal already executed");
        require(p.voteCount >= quorum, "Not enough votes");
        p.executed = true;
        (bool success, ) = p.recipient.call{value: p.amount}("");
        require(success, "Transfer failed");
        emit ProposalExecuted(proposalId);
    }

    function isValidDelegate(address _delegate) internal view returns (bool) {
        for (uint256 i = 0; i < delegates.length; i++) {
            if (delegates[i] == _delegate) {
                return true;
            }
        }
        return false;
    }
}