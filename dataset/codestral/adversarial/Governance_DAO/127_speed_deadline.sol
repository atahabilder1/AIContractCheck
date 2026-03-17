// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Governance {
    address public owner;
    mapping(address => bool) public voters;

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

    modifier onlyVoter() {
        require(voters[msg.sender], "Only registered voters can call this function.");
        _;
    }

    struct Proposal {
        string description;
        uint votes;
    }

    mapping(uint => Proposal) public proposals;
    uint public proposalCount;

    function createProposal(string memory _description) public onlyVoter {
        proposalCount++;
        proposals[proposalCount] = Proposal(_description, 0);
    }

    function vote(uint _proposalId) public onlyVoter {
        proposals[_proposalId].votes += 1;
    }
}