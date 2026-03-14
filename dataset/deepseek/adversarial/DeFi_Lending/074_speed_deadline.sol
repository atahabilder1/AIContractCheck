// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeFiLending is Ownable {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 startDate;
        uint256 endDate;
        bool repaid;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public loanCount;

    IERC20 public token;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount, uint256 interestRate, uint256 endDate);
    event LoanRepaid(uint256 indexed loanId, bool repaid);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function createLoan(address borrower, uint256 amount, uint256 interestRate, uint256 durationInDays) external onlyOwner {
        require(borrower != address(0), "Borrower address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");
        require(interestRate > 0, "Interest rate must be greater than zero");
        require(durationInDays > 0, "Duration must be greater than zero");

        uint256 endDate = block.timestamp + durationInDays * 1 days;
        loans[loanCount] = Loan({
            borrower: borrower,
            amount: amount,
            interestRate: interestRate,
            startDate: block.timestamp,
            endDate: endDate,
            repaid: false
        });

        token.transfer(borrower, amount);
        loanCount++;

        emit LoanCreated(loanCount - 1, borrower, amount, interestRate, endDate);
    }

    function repayLoan(uint256 loanId) external {
        require(loanId < loanCount, "Loan does not exist");
        Loan storage loan = loans[loanId];
        require(!loan.repaid, "Loan already repaid");
        require(msg.sender == loan.borrower, "Only borrower can repay the loan");

        uint256 totalAmount = loan.amount + calculateInterest(loanId);
        token.transferFrom(msg.sender, address(this), totalAmount);
        loan.repaid = true;

        emit LoanRepaid(loanId, true);
    }

    function calculateInterest(uint256 loanId) public view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 daysPassed = (block.timestamp - loan.startDate) / 1 days;
        uint256 interest = (loan.amount * loan.interestRate * daysPassed) / 100 / 365;
        return interest;
    }

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        require(loanId < loanCount, "Loan does not exist");
        return loans[loanId];
    }
}