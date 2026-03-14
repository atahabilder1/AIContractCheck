// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public raisedAmount;
    mapping(address => uint256) public contributions;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event GoalReached(uint256 amountRaised);
    event GoalNotReached();

    constructor(uint256 _goal) {
        owner = msg.sender;
        goal = _goal;
    }

    function contribute() public payable {
        require(msg.value > 0, "Contribution must be greater than zero");
        contributions[msg.sender] += msg.value;
        raisedAmount += msg.value;
        emit ContributionReceived(msg.sender, msg.value);
    }

    function withdraw() public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(raisedAmount >= goal, "Goal not reached");
        payable(owner).transfer(address(this).balance);
        emit GoalReached(raisedAmount);
    }

    function refund(address payable contributor) public {
        require(msg.sender == owner, "Only owner can refund");
        require(raisedAmount < goal, "Goal reached, no refunds");
        uint256 contribution = contributions[contributor];
        require(contribution > 0, "No contribution to refund");
        contributions[contributor] = 0;
        payable(contributor).transfer(contribution);
    }
}