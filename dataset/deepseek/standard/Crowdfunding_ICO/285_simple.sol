// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public raisedAmount;
    bool public goalReached;
    mapping(address => uint256) public contributions;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event GoalReached();
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

    function checkGoalStatus() public view returns (bool) {
        return raisedAmount >= goal;
    }

    function withdraw() public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(!goalReached, "Goal has already been reached");
        require(checkGoalStatus(), "Goal not yet reached");
        goalReached = true;
        emit GoalReached();
        payable(owner).transfer(address(this).balance);
    }

    function refund(address payable contributor) public {
        require(msg.sender == owner, "Only owner can refund");
        require(!checkGoalStatus(), "Goal has already been reached");
        uint256 contribution = contributions[contributor];
        require(contribution > 0, "No contribution to refund");
        contributions[contributor] = 0;
        (bool success, ) = contributor.call{value: contribution}("");
        require(success, "Refund transfer failed");
    }
}