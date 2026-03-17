// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SimpleGovernance {
    address[] public members;
    mapping(address => bool) public isMember;
    mapping(string => bool) public proposals;

    constructor() {
        members.push(msg.sender);
        isMember[msg.sender] = true;
    }

    function joinDAO() public {
        require(!isMember[msg.sender], "You are already a member.");
        members.push(msg.sender);
        isMember[msg.sender] = true;
    }

    function propose(string memory proposal) public {
        require(isMember[msg.sender], "Only members can propose.");
        require(!proposals[proposal], "Proposal already exists.");
        proposals[proposal] = true;
    }

    function execute(string memory proposal) public {
        require(isMember[msg.sender], "Only members can execute.");
        require(proposals[proposal], "Proposal does not exist.");
        // Add execution logic here
        proposals[proposal] = false;
    }
}