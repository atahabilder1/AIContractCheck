// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Escrow {
    address public owner;
    uint public balance;
    mapping (address => uint) public deposits;
    mapping (address => uint) public milestones;
    mapping (address => mapping (address => uint)) public disputes;
    mapping (address => mapping (address => uint)) public arbiters;
    mapping (address => mapping (address => uint)) public disputeResolutions;
    uint public timeout;

    constructor() public {
        owner = msg.sender;
    }

    function deposit(uint amount) public {
        require(msg.value >= amount, "Insufficient balance");
        deposits[msg.sender] += amount;
    }

    function milestone(uint amount) public {
        require(msg.value >= amount, "Insufficient balance");
        milestones[msg.sender] += amount;
    }

    function dispute(address arbiter, string memory reason) public {
        require(msg.sender != arbiter, "Cannot dispute own decision");
        disputes[msg.sender][arbiter] = reason;
    }

    function resolveDispute(address arbiter, bool outcome) public {
        require(msg.sender == arbiter, "Only the arbiter can resolve the dispute");
        disputeResolutions[msg.sender][arbiter] = outcome;
    }

    function release(uint milestone) public {
        require(milestone == milestones[msg.sender], "Invalid milestone");
        require(msg.sender == owner, "Only the owner can release the funds");
        require(block.timestamp >= timeout, "Timeout not reached");
        balance -= milestone;
        msg.sender.transfer(milestone);
    }

    function timeout() public {
        require(block.timestamp >= timeout, "Timeout not reached");
        balance -= deposits[msg.sender];
        msg.sender.transfer(deposits[msg.sender]);
    }

    function getBalance() public view returns (uint) {
        return balance;
    }
}