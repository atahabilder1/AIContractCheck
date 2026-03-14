// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 startTimestamp;
        uint256 endTimestamp;
        bool isActive;
    }

    mapping(address => Loan) public loans;
    uint256 public loanCount;

    event LoanCreated(address indexed borrower, uint256 amount, uint256 interestRate, uint256 startTimestamp, uint256 endTimestamp);
    event LoanRepaid(address indexed borrower, uint256 amountPaid);
    event LoanDefaulted(address indexed borrower, uint256 amountOwed);

    function createLoan(uint256 amount, uint256 interestRate, uint256 durationInDays) public {
        require(amount > 0, "Amount must be greater than zero");
        require(interestRate > 0, "Interest rate must be greater than zero");
        require(durationInDays > 0, "Duration must be greater than zero");

        uint256 endTimestamp = block.timestamp + durationInDays * 1 days;
        loans[msg.sender] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: interestRate,
            startTimestamp: block.timestamp,
            endTimestamp: endTimestamp,
            isActive: true
        });

        loanCount++;
        emit LoanCreated(msg.sender, amount, interestRate, block.timestamp, endTimestamp);
    }

    function repayLoan() public payable {
        Loan storage loan = loans[msg.sender];
        require(loan.isActive, "Loan is not active");
        require(msg.value >= loan.amount, "Insufficient amount to repay the loan");

        uint256 interest = calculateInterest(loan.amount, loan.interestRate, loan.startTimestamp, loan.endTimestamp);
        uint256 totalAmount = loan.amount + interest;

        if (msg.value >= totalAmount) {
            loan.borrower.transfer(loan.amount);
            if (msg.value > totalAmount) {
                loan.borrower.transfer(msg.value - totalAmount);
            }
        } else {
            loan.borrower.transfer(msg.value);
        }

        loan.isActive = false;
        emit LoanRepaid(msg.sender, msg.value);
    }

    function calculateInterest(uint256 principal, uint256 rate, uint256 start, uint256 end) public pure returns (uint256) {
        uint256 interest = principal * rate * (end - start) / 100 / 1 days;
        return interest;
    }

    function getLoanDetails(address borrower) public view returns (Loan memory) {
        return loans[borrower];
    }
}