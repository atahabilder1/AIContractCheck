SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract SimpleGovernance {
    address public owner;
    mapping(address => bool) public voters;
    mapping(bytes32 => uint256) public proposals;
    mapping(bytes32 => bool) public proposalVoted;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function.");
        _;
    }

    function registerVoter(address voter) public onlyOwner {
        voters[voter] = true;
    }

    function createProposal(bytes32 proposalHash) public {
        require(voters[msg.sender], "Only registered voters can create proposals.");
        require(!proposalVoted[proposalHash], "This proposal has already been voted on.");
        proposals[proposalHash] = 0;
    }

    function vote(bytes32 proposalHash, bool support) public {
        require(voters[msg.sender], "Only registered voters can vote.");
        require(!proposalVoted[proposalHash], "You have already voted on this proposal.");
        if (support) {
            proposals[proposalHash]++;
        }
        proposalVoted[proposalHash] = true;
    }

    function executeProposal(bytes32 proposalHash) public onlyOwner {
        require(proposalVoted[proposalHash], "This proposal has not been voted on yet.");
        // Execute the proposal here, e.g., by calling another contract or transferring funds.
    }
}