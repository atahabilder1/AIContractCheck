// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LendingProtocol {
    struct Borrower {
        uint256 totalBorrowed;
        uint256 totalCollateral;
        uint256 interestRate;
    }

    mapping(address => Borrower) public borrowers;

    function deposit(uint256 amount) public {
        borrowers[msg.sender].totalCollateral += amount;
    }

    function withdraw(uint256 amount) public {
        require(borrowers[msg.sender].totalCollateral >= amount, "Insufficient collateral");
        borrowers[msg.sender].totalCollateral -= amount;
    }

    function borrow(uint256 amount, uint256 interestRate) public {
        require(calculateHealthFactor(msg.sender) > 1, "Unsafe operation");
        borrowers[msg.sender].totalBorrowed += amount;
        borrowers[msg.sender].interestRate = interestRate;
    }

    function repay(uint256 amount) public {
        require(borrowers[msg.sender].totalBorrowed >= amount, "Insufficient debt");
        borrowers[msg.sender].totalBorrowed -= amount;
    }

    function calculateHealthFactor(address account) public view returns (uint256) {
        uint256 totalCollateral = borrowers[account].totalCollateral;
        uint256 totalDebt = borrowers[account].totalBorrowed * (1 + borrowers[account].interestRate / 100);
        return totalCollateral > 0 ? totalDebt * 1e18 / totalCollateral : 0;
    }
}