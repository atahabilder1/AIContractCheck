// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public raisedAmount;
    bool public isFundingSuccessful;

    mapping(address => uint) public contributions;

    event FundingReceived(address contributor, uint amount);
    event GoalReached(uint totalAmountRaised);
    event RefundSent(address recipient, uint amount);

    constructor(uint _goal, uint _durationInMinutes) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + (_durationInMinutes * 1 minutes);
        isFundingSuccessful = false;
    }

    function contribute() external payable {
        require(block.timestamp < deadline, "Funding period has ended.");
        require(!isFundingSuccessful, "Funding goal has been reached.");
        require(msg.value > 0, "Contribution must be greater than 0.");

        contributions[msg.sender] += msg.value;
        raisedAmount += msg.value;

        emit FundingReceived(msg.sender, msg.value);

        if (raisedAmount >= goal) {
            isFundingSuccessful = true;
            emit GoalReached(raisedAmount);
        }
    }

    function claimRefund() external {
        require(block.timestamp >= deadline, "Funding period has not ended.");
        require(!isFundingSuccessful, "Funding goal has been reached, no refunds.");
        require(contributions[msg.sender] > 0, "No contributions to refund.");

        uint refundAmount = contributions[msg.sender];
        contributions[msg.sender] = 0;

        payable(msg.sender).transfer(refundAmount);
        emit RefundSent(msg.sender, refundAmount);
    }

    function withdrawFunds() external {
        require(msg.sender == owner, "Only the owner can withdraw funds.");
        require(isFundingSuccessful, "Funding goal has not been reached.");
        require(raisedAmount > 0, "No funds to withdraw.");

        payable(owner).transfer(raisedAmount);
    }
}