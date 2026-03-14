// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 start;
        uint256 duration;
        bool repaid;
    }

    uint256 public loanCount;
    mapping(uint256 => Loan) public loans;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount, uint256 interestRate, uint256 duration);
    event LoanRepaid(uint256 indexed loanId);

    function createLoan(uint256 amount, uint256 interestRate, uint256 duration) public {
        loanCount++;
        loans[loanCount] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: interestRate,
            start: block.timestamp,
            duration: duration,
            repaid: false
        });
        emit LoanCreated(loanCount, msg.sender, amount, interestRate, duration);
    }

    function repayLoan(uint256 loanId) public payable {
        require(loanId <= loanCount, "Loan does not exist");
        Loan storage loan = loans[loanId];
        require(!loan.repaid, "Loan already repaid");
        require(msg.sender == loan.borrower, "Only the borrower can repay the loan");
        require(msg.value >= loan.amount + calculateInterest(loanId), "Amount sent is less than the required repayment");

        loan.repaid = true;
        payable(loan.borrower).transfer(loan.amount);
        emit LoanRepaid(loanId);
    }

    function calculateInterest(uint256 loanId) public view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 interest = loan.amount * loan.interestRate * (block.timestamp - loan.start) / 100 / 365 days;
        return interest;
    }
}