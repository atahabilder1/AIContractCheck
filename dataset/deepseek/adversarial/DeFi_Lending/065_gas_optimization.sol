// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public interestRates;
    uint256 public totalSupply;

    function deposit(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        balances[msg.sender] += amount;
        deposits[msg.sender] += amount;
        totalSupply += amount;
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        payable(msg.sender).transfer(amount);
    }

    function borrow(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        // Assuming interest is accrued and added to the borrower's balance
        interestRates[msg.sender] += amount;
    }

    function repay(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(interestRates[msg.sender] >= amount, "Repayment exceeds outstanding debt");
        balances[msg.sender] += amount;
        interestRates[msg.sender] -= amount;
    }

    function getDepositBalance(address user) public view returns (uint256) {
        return deposits[user];
    }

    function getBorrowedBalance(address user) public view returns (uint256) {
        return interestRates[user];
    }
}