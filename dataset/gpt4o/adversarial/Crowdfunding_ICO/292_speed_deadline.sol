// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint256 public fundingGoal;
    uint256 public totalFunds;
    uint256 public deadline;
    mapping(address => uint256) public contributions;
    bool public goalReached;
    bool public fundsWithdrawn;

    event ContributionReceived(address contributor, uint256 amount);
    event GoalReached(uint256 totalFunds);
    event FundsWithdrawn(address recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier afterDeadline() {
        require(block.timestamp >= deadline, "Deadline not yet reached");
        _;
    }

    constructor(uint256 _fundingGoal, uint256 _durationInMinutes) {
        owner = msg.sender;
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationInMinutes * 1 minutes);
        totalFunds = 0;
        goalReached = false;
        fundsWithdrawn = false;
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "Crowdfunding period ended");
        require(msg.value > 0, "Contribution must be greater than zero");

        contributions[msg.sender] += msg.value;
        totalFunds += msg.value;

        emit ContributionReceived(msg.sender, msg.value);

        if (totalFunds >= fundingGoal && !goalReached) {
            goalReached = true;
            emit GoalReached(totalFunds);
        }
    }

    function withdrawFunds() public onlyOwner afterDeadline {
        require(goalReached, "Funding goal not reached");
        require(!fundsWithdrawn, "Funds already withdrawn");

        uint256 amount = address(this).balance;
        fundsWithdrawn = true;
        payable(owner).transfer(amount);

        emit FundsWithdrawn(owner, amount);
    }

    function refund() public afterDeadline {
        require(!goalReached, "Funding goal was reached");
        require(contributions[msg.sender] > 0, "No contributions to refund");

        uint256 amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}