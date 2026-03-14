// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public totalContributed;
    mapping(address => uint) public contributions;
    bool public goalReached;
    bool public refundsEnabled;

    event ContributionReceived(address contributor, uint amount);
    event GoalReached();
    event RefundsEnabled();
    event Refunded(address contributor, uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Deadline has passed");
        _;
    }

    modifier afterDeadline() {
        require(block.timestamp >= deadline, "Deadline has not passed yet");
        _;
    }

    constructor(uint _goal, uint _duration) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _duration;
    }

    function contribute() external payable beforeDeadline {
        require(msg.value > 0, "Contribution must be greater than zero");
        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;
        
        emit ContributionReceived(msg.sender, msg.value);

        if (totalContributed >= goal && !goalReached) {
            goalReached = true;
            emit GoalReached();
        }
    }

    function enableRefunds() external onlyOwner afterDeadline {
        require(!goalReached, "Goal was reached, no refunds");
        refundsEnabled = true;
        emit RefundsEnabled();
    }

    function getRefund() external afterDeadline {
        require(refundsEnabled, "Refunds are not enabled");
        uint contribution = contributions[msg.sender];
        require(contribution > 0, "No contributions to refund");
        
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(contribution);
        emit Refunded(msg.sender, contribution);
    }

    function withdraw() external onlyOwner afterDeadline {
        require(goalReached, "Goal not reached, cannot withdraw");
        payable(owner).transfer(totalContributed);
    }
}