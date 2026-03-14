// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigGovernance {
    address[] public proposals;
    address[] public approvedProposals;
    address[] public rejectedProposals;
    address[] public councilMembers;
    mapping(address => mapping(uint256 => uint256)) public votes;

    constructor(address[] memory _councilMembers) {
        councilMembers = _councilMembers;
    }

    function createProposal(string memory _name, string memory _description) public {
        require(bytes(_name).length > 0, "Name must not be empty");
        require(bytes(_description).length > 0, "Description must not be empty");

        proposals.push(msg.sender);
        emit ProposalCreated(msg.sender, _name, _description);
    }

    function vote(uint256 _proposalId, bool _support) public {
        require(_proposalId < proposals.length, "Invalid proposal id");

        address voter = msg.sender;
        uint256 support = _support ? 1 : 0;

        votes[voter][_proposalId] = support;
        emit VoteCast(voter, _proposalId, support);
    }

    function approveProposal(uint256 _proposalId) public {
        require(_proposalId < proposals.length, "Invalid proposal id");

        address proposer = proposals[_proposalId];

        if (votes[proposer][_proposalId] == 1) {
            approvedProposals.push(_proposalId);
            emit ProposalApproved(_proposalId);
        } else {
            rejectedProposals.push(_proposalId);
            emit ProposalRejected(_proposalId);
        }
    }

    function getProposal(uint256 _proposalId) public view returns (Proposal memory) {
        require(_proposalId < proposals.length, "Invalid proposal id");

        Proposal memory proposal = Proposal(proposals[_proposalId], councilMembers, votes[proposals[_proposalId]]);
        return proposal;
    }

    function getProposals() public view returns (Proposal[] memory) {
        return proposals;
    }

    function getApprovedProposals() public view returns (Proposal[] memory) {
        return approvedProposals;
    }

    function getRejectedProposals() public view returns (Proposal[] memory) {
        return rejectedProposals;
    }
}