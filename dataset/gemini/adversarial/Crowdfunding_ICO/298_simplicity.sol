// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MinimalCrowdfunding {
    address payable public owner;
    uint256 public fundingGoal;
    uint256 public deadline;
    uint256 public raisedAmount;
    bool public projectCompleted = false;
    bool public projectFailed = false;

    mapping(address => uint256) public contributors;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event ProjectCompleted(uint256 totalRaised);
    event ProjectFailed(uint256 totalRaised);
    event RefundIssued(address indexed contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Action not allowed after deadline");
        _;
    }

    modifier afterDeadline() {
        require(block.timestamp >= deadline, "Action not allowed before deadline");
        _;
    }

    constructor(uint256 _fundingGoal, uint256 _durationInDays) {
        owner = payable(msg.sender);
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    function contribute() public payable beforeDeadline {
        require(msg.value > 0, "Contribution must be greater than zero");
        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;
        emit ContributionReceived(msg.sender, msg.value);
    }

    function checkProjectStatus() public {
        if (projectCompleted || projectFailed) {
            return;
        }

        if (block.timestamp >= deadline) {
            if (raisedAmount >= fundingGoal) {
                projectCompleted = true;
                emit ProjectCompleted(raisedAmount);
            } else {
                projectFailed = true;
                emit ProjectFailed(raisedAmount);
            }
        }
    }

    function withdrawFunds() public onlyOwner afterDeadline {
        require(projectCompleted, "Project must be completed to withdraw funds");
        require(raisedAmount > 0, "No funds to withdraw");

        uint256 amountToWithdraw = raisedAmount;
        raisedAmount = 0; // Reset raised amount after withdrawal

        (bool success, ) = owner.call{value: amountToWithdraw}("");
        require(success, "Fund withdrawal failed");
    }

    function refundContributions() public afterDeadline {
        require(projectFailed, "Project must have failed to issue refunds");
        require(contributors[msg.sender] > 0, "You have not contributed or already refunded");

        uint256 refundAmount = contributors[msg.sender];
        contributors[msg.sender] = 0; // Mark as refunded

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund failed");
        emit RefundIssued(msg.sender, refundAmount);
    }

    receive() external payable {
        contribute();
    }
}