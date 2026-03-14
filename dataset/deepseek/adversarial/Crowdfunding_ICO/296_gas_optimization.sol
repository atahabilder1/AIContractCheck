// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint256 public target;
    uint256 public raisedAmount;
    uint256 public deadline;
    mapping(address => uint256) public contributions;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event GoalReached(uint256 amountRaised);
    event Refund(address indexed contributor, uint256 amount);

    constructor(uint256 _target, uint256 _duration) {
        require(_target > 0, "Target amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        owner = msg.sender;
        target = _target;
        deadline = block.timestamp + _duration;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "Deadline has passed");
        require(msg.value > 0, "Contribution must be greater than 0");

        contributions[msg.sender] += msg.value;
        raisedAmount += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    function withdraw() public onlyOwner {
        require(block.timestamp >= deadline && raisedAmount >= target, "Cannot withdraw yet");
        uint256 balance = address(this).balance;
        require(balance > 0, "Contract balance is zero");
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Transfer failed");
    }

    function refund(uint256 amount) public {
        require(block.timestamp >= deadline && raisedAmount < target, "Refund is not allowed yet");
        require(contributions[msg.sender] >= amount, "Insufficient contribution");

        contributions[msg.sender] -= amount;
        raisedAmount -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Refund transfer failed");

        emit Refund(msg.sender, amount);
    }
}