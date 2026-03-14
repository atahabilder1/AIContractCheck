// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    // Variables
    uint256 public totalFlashLoans;
    uint256 public totalFlashLoanValue;
    mapping(address => uint256) public flashLoanBalances;

    // Events
    event FlashLoanRequested(address indexed borrower, uint256 indexed amount);
    event FlashLoanRepaid(address indexed borrower, uint256 indexed amount);

    // Functions
    function requestFlashLoan(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(msg.sender.balance >= amount, "Insufficient balance");

        totalFlashLoans += 1;
        totalFlashLoanValue += amount;
        flashLoanBalances[msg.sender] += amount;

        emit FlashLoanRequested(msg.sender, amount);
    }

    function repayFlashLoan(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(amount <= flashLoanBalances[msg.sender], "Insufficient balance");

        totalFlashLoanValue -= amount;
        flashLoanBalances[msg.sender] -= amount;

        emit FlashLoanRepaid(msg.sender, amount);
    }
}