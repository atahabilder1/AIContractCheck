// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    struct UserDeposit {
        uint256 amount;
        uint256 depositTime;
    }

    mapping(address => UserDeposit) public userDeposits;
    uint256 public totalDeposits;
    uint256 public constant interestRate = 5; // 5% annual interest
    uint256 public constant yearInSeconds = 365 days;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 interest);

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        
        if (userDeposits[msg.sender].amount > 0) {
            uint256 pendingInterest = calculateInterest(msg.sender);
            userDeposits[msg.sender].amount += pendingInterest;
        }

        userDeposits[msg.sender].amount += msg.value;
        userDeposits[msg.sender].depositTime = block.timestamp;
        totalDeposits += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        require(userDeposits[msg.sender].amount > 0, "No funds to withdraw");

        uint256 userBalance = userDeposits[msg.sender].amount;
        uint256 interest = calculateInterest(msg.sender);

        uint256 totalAmount = userBalance + interest;
        totalDeposits -= userBalance;

        userDeposits[msg.sender].amount = 0;
        userDeposits[msg.sender].depositTime = 0;

        payable(msg.sender).transfer(totalAmount);

        emit Withdraw(msg.sender, userBalance, interest);
    }

    function calculateInterest(address user) internal view returns (uint256) {
        UserDeposit memory userDeposit = userDeposits[user];
        uint256 timeElapsed = block.timestamp - userDeposit.depositTime;
        uint256 interest = (userDeposit.amount * interestRate * timeElapsed) / (100 * yearInSeconds);
        return interest;
    }

    function getUserDeposit(address user) external view returns (uint256, uint256) {
        return (userDeposits[user].amount, userDeposits[user].depositTime);
    }
}