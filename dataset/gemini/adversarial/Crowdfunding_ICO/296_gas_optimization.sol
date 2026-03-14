// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract GasOptimizedCrowdfund {
    address public owner;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public goalAmount;
    uint256 public raisedAmount;
    bool public crowdfundingClosed = false;

    mapping(address => uint256) public contributors;

    event Contribution(address indexed contributor, uint256 amount);
    event Refund(address indexed contributor, uint256 amount);
    event GoalReached(uint256 totalRaised);
    event CrowdfundingEnded(bool goalReached);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyDuringCrowdfunding() {
        require(block.timestamp >= startTime && block.timestamp < endTime, "Crowdfunding is not active");
        _;
    }

    modifier onlyAfterCrowdfunding() {
        require(block.timestamp >= endTime, "Crowdfunding has not ended yet");
        _;
    }

    constructor(
        uint256 _startTime,
        uint256 _duration,
        uint256 _goalAmount
    ) {
        owner = msg.sender;
        startTime = _startTime;
        endTime = _startTime + _duration;
        goalAmount = _goalAmount;
    }

    function contribute() external payable onlyDuringCrowdfunding {
        require(msg.value > 0, "Contribution must be positive");
        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;
        emit Contribution(msg.sender, msg.value);
    }

    function endCrowdfunding() public onlyOwner onlyAfterCrowdfunding {
        require(!crowdfundingClosed, "Crowdfunding already ended");
        crowdfundingClosed = true;

        if (raisedAmount >= goalAmount) {
            emit GoalReached(raisedAmount);
        }
        emit CrowdfundingEnded(raisedAmount >= goalAmount);
    }

    function withdraw() public onlyOwner onlyAfterCrowdfunding {
        require(crowdfundingClosed, "Crowdfunding must be ended to withdraw");
        require(raisedAmount >= goalAmount, "Goal not reached");
        require(address(this).balance >= goalAmount, "Not enough balance to withdraw goal");

        uint256 amountToWithdraw = address(this).balance; // Withdraw all available balance if goal is met
        (bool success, ) = payable(owner).call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed");
    }

    function claimRefund() public onlyAfterCrowdfunding {
        require(crowdfundingClosed, "Crowdfunding must be ended to claim refund");
        require(raisedAmount < goalAmount, "Goal was reached, no refunds");

        uint256 amountToRefund = contributors[msg.sender];
        require(amountToRefund > 0, "No contribution to refund");

        contributors[msg.sender] = 0; // Zero out before sending to prevent reentrancy
        (bool success, ) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund failed");
        emit Refund(msg.sender, amountToRefund);
    }

    // Fallback function to receive Ether, can be used for initial contribution if not explicitly calling contribute()
    receive() external payable onlyDuringCrowdfunding {
        contribute();
    }

    // Helper function to check current status
    function getCrowdfundingStatus() public view returns (uint256, uint256, uint256, uint256, bool) {
        return (startTime, endTime, goalAmount, raisedAmount, crowdfundingClosed);
    }

    // Helper function for contributors to check their contribution
    function getMyContribution() public view returns (uint256) {
        return contributors[msg.sender];
    }
}