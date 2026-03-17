// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PeerToPeerLending {
    struct Loan {
        address lender;
        address borrower;
        uint amount;
        uint interestRate;
        uint duration;
        bool repaid;
    }

    mapping(uint => Loan) public loans;
    uint public loanCount = 0;

    constructor() {}

    function createLoan(address _borrower, uint _amount, uint _interestRate, uint _duration) public payable {
        require(_amount > 0 && _interestRate > 0 && _duration > 0, "Invalid loan terms");
        require(msg.value >= _amount, "Insufficient funds sent for the loan amount");

        loans[loanCount] = Loan({
            lender: msg.sender,
            borrower: _borrower,
            amount: _amount,
            interestRate: _interestRate,
            duration: _duration,
            repaid: false
        });

        loanCount++;
    }

    function repayLoan(uint _loanId) public {
        Loan memory loan = loans[_loanId];
        require(!loan.repaid && msg.sender == loan.borrower, "Invalid repayment");

        uint totalAmount = loan.amount + (loan.amount * loan.interestRate / 100);
        payable(loan.lender).transfer(totalAmount);
        loans[_loanId].repaid = true;
    }
}