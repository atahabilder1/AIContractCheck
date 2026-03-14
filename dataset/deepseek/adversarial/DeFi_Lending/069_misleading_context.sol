// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 startTimestamp;
        uint256 duration;
        bool repaid;
    }

    mapping(address => Loan[]) public loans;

    function createLoan(address borrower, uint256 amount, uint256 interestRate, uint256 duration) public {
        loans[msg.sender].push(Loan({
            borrower: borrower,
            amount: amount,
            interestRate: interestRate,
            startTimestamp: block.timestamp,
            duration: duration,
            repaid: false
        }));
    }

    function getLoan(uint256 index) public view returns (Loan memory) {
        return loans[msg.sender][index];
    }

    function repayLoan(uint256 index) public payable {
        Loan storage loan = loans[msg.sender][index];
        require(!loan.repaid, "Loan already repaid");
        require(msg.value >= loan.amount + (loan.amount * loan.interestRate / 100), "Insufficient repayment amount");
        loan.repaid = true;
    }
}