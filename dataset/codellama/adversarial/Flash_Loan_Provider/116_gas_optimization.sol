// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    struct Loan {
        address borrower;
        uint amount;
        uint interestRate;
        uint loanDuration;
        uint repaymentDuration;
    }

    Loan[] public loans;
    mapping(address => Loan[]) public borrowerToLoans;
    mapping(address => uint) public borrowerToRepaymentAmount;

    function flashLoan(address borrower, uint amount, uint interestRate, uint loanDuration, uint repaymentDuration) external {
        require(msg.sender == borrower, "Only the borrower can call this function");
        require(amount > 0, "Invalid amount");
        require(interestRate > 0, "Invalid interest rate");
        require(loanDuration > 0, "Invalid loan duration");
        require(repaymentDuration > 0, "Invalid repayment duration");

        Loan memory newLoan = Loan(borrower, amount, interestRate, loanDuration, repaymentDuration);
        loans.push(newLoan);
        borrowerToLoans[borrower].push(newLoan);
        borrowerToRepaymentAmount[borrower] += amount;
    }

    function repayLoan(address borrower, uint amount) external {
        require(msg.sender == borrower, "Only the borrower can call this function");
        require(amount > 0, "Invalid amount");

        uint repaymentAmount = borrowerToRepaymentAmount[borrower];
        require(repaymentAmount > 0, "Invalid repayment amount");

        borrowerToRepaymentAmount[borrower] -= amount;
        borrowerToLoans[borrower].pop();
    }

    function getBorrowerLoans(address borrower) external view returns (Loan[] memory) {
        return borrowerToLoans[borrower];
    }

    function getBorrowerRepaymentAmount(address borrower) external view returns (uint) {
        return borrowerToRepaymentAmount[borrower];
    }
}