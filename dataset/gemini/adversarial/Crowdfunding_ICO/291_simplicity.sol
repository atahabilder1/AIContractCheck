// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrowdfund {
    address payable public owner;
    uint256 public fundingGoal;
    uint256 public amountRaised;
    uint256 public deadline;
    bool public goalReached = false;
    bool public ended = false;

    struct Contributor {
        uint256 amount;
        bool claimed;
    }

    mapping(address => Contributor) public contributors;
    address[] public contributorAddresses;

    event Contribution(address indexed contributor, uint256 amount);
    event GoalReached(uint256 totalAmount);
    event Refund(address indexed contributor, uint256 amount);
    event ProjectFundsWithdraw(address indexed owner, uint256 amount);

    constructor(uint256 _fundingGoal, uint256 _durationInDays) {
        owner = payable(msg.sender);
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "Crowdfunding has ended.");
        require(msg.value > 0, "Contribution must be greater than zero.");

        contributors[msg.sender].amount += msg.value;
        amountRaised += msg.value;

        if (contributors[msg.sender].amount == msg.value) {
            contributorAddresses.push(msg.sender);
        }

        emit Contribution(msg.sender, msg.value);

        if (!goalReached && amountRaised >= fundingGoal) {
            goalReached = true;
            emit GoalReached(amountRaised);
        }
    }

    function endCrowdfund() public {
        require(msg.sender == owner, "Only owner can end the crowdfund.");
        require(!ended, "Crowdfund has already ended.");
        ended = true;
    }

    function withdrawFunds() public {
        require(msg.sender == owner, "Only owner can withdraw funds.");
        require(ended, "Crowdfund must be ended to withdraw.");
        require(goalReached, "Funding goal not reached.");
        require(amountRaised > 0, "No funds to withdraw.");

        uint256 amount = amountRaised;
        amountRaised = 0;
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Fund withdrawal failed.");
        emit ProjectFundsWithdraw(owner, amount);
    }

    function claimRefund() public {
        require(ended, "Crowdfund must be ended to claim refund.");
        require(!goalReached, "Funding goal was reached, no refunds.");
        require(contributors[msg.sender].amount > 0, "You have not contributed.");
        require(!contributors[msg.sender].claimed, "Refund already claimed.");

        uint256 amountToRefund = contributors[msg.sender].amount;
        contributors[msg.sender].amount = 0;
        contributors[msg.sender].claimed = true;

        (bool success, ) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund failed.");
        emit Refund(msg.sender, amountToRefund);
    }

    function getContributors() public view returns (address[] memory) {
        return contributorAddresses;
    }

    function getContributorInfo(address _contributor) public view returns (uint256, bool) {
        return (contributors[_contributor].amount, contributors[_contributor].claimed);
    }

    receive() external payable {
        contribute();
    }
}