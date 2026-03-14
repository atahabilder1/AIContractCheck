// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address payable public owner;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public goalAmount;
    uint256 public raisedAmount;
    mapping(address => uint256) public contributions;

    event Contribution(address indexed contributor, uint256 amount);
    event Refund(address indexed contributor, uint256 amount);
    event GoalReached(uint256 totalRaised);
    event CampaignEnded(uint256 totalRaised, bool goalReached);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier active() {
        require(block.timestamp >= startTime && block.timestamp < endTime, "Campaign not active");
        _;
    }

    modifier ended() {
        require(block.timestamp >= endTime, "Campaign not ended");
        _;
    }

    constructor(uint256 _startTime, uint256 _endTime, uint256 _goalAmount) {
        owner = payable(msg.sender);
        startTime = _startTime;
        endTime = _endTime;
        goalAmount = _goalAmount;
    }

    function contribute() external payable active {
        require(msg.value > 0, "Contribution must be positive");
        contributions[msg.sender] += msg.value;
        raisedAmount += msg.value;
        emit Contribution(msg.sender, msg.value);
    }

    function claimFunds() external onlyOwner ended {
        require(raisedAmount >= goalAmount, "Goal not reached");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Fund transfer failed");
    }

    function refund() external ended {
        uint256 refundAmount = contributions[msg.sender];
        require(refundAmount > 0, "No contributions to refund");
        require(raisedAmount < goalAmount, "Goal was reached, no refunds");

        contributions[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund failed");
        emit Refund(msg.sender, refundAmount);
    }

    function withdrawUnclaimedFunds() external onlyOwner ended {
        require(raisedAmount < goalAmount, "Goal was reached, funds should be claimed");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Fund transfer failed");
    }

    receive() external payable {
        contribute();
    }
}