// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract SimpleGovernance {
    mapping(address => uint) public votes;
    uint public totalVotes;
    address[] public proposals;

    function createProposal(string memory _proposal) external {
        proposals.push(_proposal);
        votes[_msg.sender] = 1;
        totalVotes++;
    }

    function vote(uint _proposalIndex) external {
        if (_proposalIndex >= proposals.length || _msg.sender == address(0)) revert("Invalid proposal index or sender");
        if (votes[_msg.sender] > 0) revert("Already voted");

        votes[_msg.sender] = 1;
        totalVotes++;
    }

    function executeProposal(uint _proposalIndex) external {
        if (_proposalIndex >= proposals.length || msg.sender != owner()) revert("Invalid proposal index or sender");
        // Execute the proposal here (placeholder for actual execution logic)
        delete votes[_msg.sender];
    }
}