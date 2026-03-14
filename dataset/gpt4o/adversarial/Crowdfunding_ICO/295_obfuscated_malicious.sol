// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingICO {
    address public admin;
    bool public isPaused;
    uint256 public fundingGoal;
    uint256 public totalFundsRaised;
    uint256 public deadline;
    mapping(address => uint256) public contributions;

    event ContributionReceived(address contributor, uint256 amount);
    event Withdrawal(address recipient, uint256 amount);
    event Paused();
    event Unpaused();
    event EmergencyWithdrawal(address admin, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    constructor(uint256 _fundingGoal, uint256 _durationInDays) {
        admin = msg.sender;
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    function contribute() external payable notPaused {
        require(block.timestamp < deadline, "Funding period has ended");
        require(msg.value > 0, "Contribution must be greater than zero");

        contributions[msg.sender] += msg.value;
        totalFundsRaised += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    function withdrawFunds() external onlyAdmin notPaused {
        require(block.timestamp >= deadline, "Funding period is not over yet");
        require(totalFundsRaised >= fundingGoal, "Funding goal not met");

        uint256 amount = address(this).balance;
        payable(admin).transfer(amount);

        emit Withdrawal(admin, amount);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 amount = address(this).balance;
        payable(admin).transfer(amount);

        emit EmergencyWithdrawal(admin, amount);
    }

    function pause() external onlyAdmin {
        isPaused = true;
        emit Paused();
    }

    function unpause() external onlyAdmin {
        isPaused = false;
        emit Unpaused();
    }

    function refund() external notPaused {
        require(block.timestamp >= deadline, "Funding period is not over yet");
        require(totalFundsRaised < fundingGoal, "Funding goal was met, no refunds");

        uint256 contributedAmount = contributions[msg.sender];
        require(contributedAmount > 0, "No contributions to refund");

        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(contributedAmount);
    }

    receive() external payable {
        contribute();
    }
}