// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrowdfunding {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public raisedAmount;
    bool public isFundingSuccessful;

    mapping(address => uint) public contributions;

    event FundTransfer(address backer, uint amount, bool isContribution);
    event CampaignCompleted(uint totalRaised);

    constructor(uint _goal, uint _durationInMinutes) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + (_durationInMinutes * 1 minutes);
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "Funding period is over");
        require(msg.value > 0, "Contribution must be greater than 0");
        contributions[msg.sender] += msg.value;
        raisedAmount += msg.value;
        emit FundTransfer(msg.sender, msg.value, true);
    }

    function checkGoalReached() public {
        if (raisedAmount >= goal) {
            isFundingSuccessful = true;
            emit CampaignCompleted(raisedAmount);
        }
    }

    function withdrawFunds() public {
        require(isFundingSuccessful, "Funding goal was not reached");
        require(msg.sender == owner, "Only the owner can withdraw funds");
        payable(owner).transfer(raisedAmount);
    }

    function getRefund() public {
        require(block.timestamp > deadline, "Funding period has not ended yet");
        require(raisedAmount < goal, "Funding goal was reached");
        require(contributions[msg.sender] > 0, "No contributions found for this address");

        uint amountToRefund = contributions[msg.sender];
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amountToRefund);
        emit FundTransfer(msg.sender, amountToRefund, false);
    }
}