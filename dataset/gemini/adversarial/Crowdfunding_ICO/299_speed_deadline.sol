// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingICO {
    address payable public owner;
    uint256 public fundingGoal;
    uint256 public deadline;
    uint256 public totalRaised;
    mapping(address => uint256) public contributions;
    bool public fundingClosed = false;

    event ContributionReceived(address investor, uint256 amount);
    event FundingGoalReached(uint256 amountRaised);
    event FundingDeadlinePassed(uint256 amountRaised);
    event RefundIssued(address investor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Funding period has ended.");
        _;
    }

    modifier afterDeadline() {
        require(block.timestamp >= deadline, "Funding period has not ended yet.");
        _;
    }

    constructor(uint256 _fundingGoal, uint256 _durationInDays) {
        owner = payable(msg.sender);
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    function contribute() public payable beforeDeadline {
        require(msg.value > 0, "Contribution must be greater than zero.");
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit ContributionReceived(msg.sender, msg.value);

        if (totalRaised >= fundingGoal && !fundingClosed) {
            fundingClosed = true;
            emit FundingGoalReached(totalRaised);
        }
    }

    function closeFunding() public onlyOwner afterDeadline {
        if (!fundingClosed) {
            fundingClosed = true;
            emit FundingDeadlinePassed(totalRaised);
        }
    }

    function withdrawFunds() public onlyOwner {
        require(fundingClosed, "Funding is not yet closed.");
        require(totalRaised >= fundingGoal, "Funding goal not reached.");
        require(address(this).balance > 0, "No funds to withdraw.");

        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Fund withdrawal failed.");
    }

    function refund() public {
        require(fundingClosed, "Funding is not yet closed.");
        require(totalRaised < fundingGoal, "Funding goal was reached, no refunds.");
        require(contributions[msg.sender] > 0, "You have not contributed.");

        uint256 amountToRefund = contributions[msg.sender];
        contributions[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund failed.");
        emit RefundIssued(msg.sender, amountToRefund);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getRemainingTime() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    receive() external payable {
        contribute();
    }
}