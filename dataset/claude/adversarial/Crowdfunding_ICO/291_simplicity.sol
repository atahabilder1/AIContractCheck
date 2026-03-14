// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalRaised;
    bool public claimed;

    mapping(address => uint256) public contributions;

    constructor(uint256 _goal, uint256 _durationSeconds) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _durationSeconds;
    }

    function contribute() external payable {
        require(block.timestamp < deadline, "Campaign ended");
        require(msg.value > 0, "Must send ETH");
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
    }

    function claim() external {
        require(msg.sender == owner, "Not owner");
        require(block.timestamp >= deadline, "Campaign not ended");
        require(totalRaised >= goal, "Goal not reached");
        require(!claimed, "Already claimed");
        claimed = true;
        payable(owner).transfer(totalRaised);
    }

    function refund() external {
        require(block.timestamp >= deadline, "Campaign not ended");
        require(totalRaised < goal, "Goal was reached");
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}