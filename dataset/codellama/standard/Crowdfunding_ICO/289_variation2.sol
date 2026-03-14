// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint public deadline;
    uint public goal;
    uint public amountRaised;
    uint public stablecoinRate;
    mapping(address => uint) public contributions;

    constructor(uint _deadline, uint _goal, uint _stablecoinRate) public {
        owner = msg.sender;
        deadline = _deadline;
        goal = _goal;
        amountRaised = 0;
        stablecoinRate = _stablecoinRate;
    }

    function contribute(uint amount) public payable {
        require(block.timestamp < deadline, "Deadline has passed");
        require(amount > 0, "Invalid contribution amount");
        uint convertedAmount = amount * stablecoinRate;
        require(convertedAmount <= amountRaised, "Insufficient funds");
        amountRaised += convertedAmount;
        contributions[msg.sender] += convertedAmount;
    }

    function refund() public {
        require(block.timestamp > deadline, "Deadline has not passed");
        require(amountRaised < goal, "Goal met");
        uint refundAmount = contributions[msg.sender];
        require(refundAmount > 0, "Invalid refund amount");
        amountRaised -= refundAmount;
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(refundAmount);
    }

    function withdraw() public {
        require(block.timestamp > deadline, "Deadline has not passed");
        require(amountRaised >= goal, "Goal not met");
        uint withdrawAmount = amountRaised;
        require(withdrawAmount > 0, "Invalid withdraw amount");
        amountRaised = 0;
        payable(owner).transfer(withdrawAmount);
    }
}