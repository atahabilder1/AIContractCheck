// SPDX-License-Identifier: MIT
   pragma solidity ^0.8.17;

   import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

   contract SimpleDeFiLending {
       IERC20 public token;
       mapping(address => uint) public balances;
       mapping(address => uint) public borrowed;
       uint public interestRate = 10; // 10% per year

       constructor(IERC20 _token) {
           token = _token;
       }

       function deposit(uint amount) external {
           require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
           balances[msg.sender] += amount;
       }

       function borrow(uint amount) external {
           uint collateralNeeded = (amount * 105) / 100; // Borrower needs to provide 105% of the amount as collateral
           require(balances[msg.sender] >= collateralNeeded, "Insufficient collateral");
           borrowed[msg.sender] += amount;
       }

       function repayBorrow(uint amount) external {
           uint interest = (amount * interestRate) / 100; // Calculate interest based on the original borrowed amount
           require(token.transferFrom(msg.sender, address(this), amount + interest), "Transfer failed");
           borrowed[msg.sender] -= amount;
       }
   }