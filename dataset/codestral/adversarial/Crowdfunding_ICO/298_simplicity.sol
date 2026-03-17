// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    address payable public owner;
    uint256 public fundingGoal;
    uint256 public amountRaised;
    mapping(address => uint256) public contributions;
    bool public fundingSuccessful;

    constructor(uint256 _fundingGoal) {
        owner = payable(msg.sender);
        fundingGoal = _fundingGoal;
    }

    function contribute() external payable {
        require(msg.value > 0, "Contribution must be greater than zero.");
        contributions[msg.sender] += msg.value;
        amountRaised += msg.value;
        if (amountRaised >= fundingGoal) {
            fundingSuccessful = true;
        }
    }

    function withdraw() external {
        require(fundingSuccessful, "Funding goal not reached.");
        require(contributions[msg.sender] > 0, "No contribution to withdraw.");
        uint256 amountToWithdraw = contributions[msg.sender];
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amountToWithdraw);
    }

    function refund() external {
        require(!fundingSuccessful, "Funding goal reached.");
        uint256 amountToRefund = contributions[msg.sender];
        require(amountToRefund > 0, "No contribution to refund.");
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amountToRefund);
    }
}