// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public endTime;
    mapping(address => uint256) public contributions;
    bool public goalReached;
    bool public fundsWithdrawn;

    event ContributionReceived(address contributor, uint256 amount);
    event GoalReached(uint256 totalAmount);
    event FundsWithdrawn(address owner, uint256 amount);

    constructor(uint256 _goal, uint256 _duration) {
        owner = msg.sender;
        goal = _goal;
        endTime = block.timestamp + _duration;
        goalReached = false;
        fundsWithdrawn = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier onlyAfterEnd() {
        require(block.timestamp > endTime, "ICO not ended yet");
        _;
    }

    function contribute() external payable {
        require(block.timestamp < endTime, "ICO has ended");
        require(msg.value > 0, "Contribution must be greater than 0");

        contributions[msg.sender] += msg.value;
        emit ContributionReceived(msg.sender, msg.value);

        if (address(this).balance >= goal && !goalReached) {
            goalReached = true;
            emit GoalReached(address(this).balance);
        }
    }

    function withdrawFunds() external onlyOwner onlyAfterEnd {
        require(goalReached, "Goal not reached, cannot withdraw funds");
        require(!fundsWithdrawn, "Funds already withdrawn");

        fundsWithdrawn = true;
        payable(owner).transfer(address(this).balance);
        emit FundsWithdrawn(owner, address(this).balance);
    }

    function refund() external onlyAfterEnd {
        require(!goalReached, "Goal was reached, no refunds");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contributions to refund");

        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}