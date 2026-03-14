// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalFunds;
    mapping(address => uint256) public contributions;
    bool public goalReached;
    bool public fundsWithdrawn;

    event ContributionReceived(address contributor, uint256 amount);
    event GoalReached(uint256 totalFunds);
    event FundsWithdrawn(address owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp <= deadline, "Deadline has passed");
        _;
    }

    modifier afterDeadline() {
        require(block.timestamp > deadline, "Deadline has not passed yet");
        _;
    }

    constructor(uint256 _goal, uint256 _duration) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _duration;
        goalReached = false;
        fundsWithdrawn = false;
    }

    function contribute() external payable beforeDeadline {
        require(msg.value > 0, "Contribution must be greater than 0");
        contributions[msg.sender] += msg.value;
        totalFunds += msg.value;

        emit ContributionReceived(msg.sender, msg.value);

        if (totalFunds >= goal && !goalReached) {
            goalReached = true;
            emit GoalReached(totalFunds);
        }
    }

    function withdrawFunds() external onlyOwner afterDeadline {
        require(goalReached, "Goal not reached");
        require(!fundsWithdrawn, "Funds already withdrawn");

        uint256 amount = address(this).balance;
        fundsWithdrawn = true;
        payable(owner).transfer(amount);

        emit FundsWithdrawn(owner, amount);
    }

    function refund() external afterDeadline {
        require(!goalReached, "Goal was reached, no refunds allowed");
        
        uint256 contributedAmount = contributions[msg.sender];
        require(contributedAmount > 0, "No contributions to refund");

        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(contributedAmount);
    }
}