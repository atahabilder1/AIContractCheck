// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    struct Loan {
        uint256 amount;
        uint256 interestRate; // in basis points
        uint256 duration; // in seconds
        uint256 startTime;
        address borrower;
        bool repaid;
    }

    mapping(address => uint256) public deposits;
    mapping(address => Loan[]) public loans;
    address public owner;
    uint256 public totalDeposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event LoanTaken(address indexed borrower, uint256 amount, uint256 interestRate, uint256 duration);
    event LoanRepaid(address indexed borrower, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function takeLoan(uint256 amount, uint256 interestRate, uint256 duration) external {
        require(amount > 0, "Loan amount must be greater than 0");
        require(totalDeposits >= amount, "Insufficient liquidity in the pool");

        loans[msg.sender].push(Loan({
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            borrower: msg.sender,
            repaid: false
        }));

        payable(msg.sender).transfer(amount);
        totalDeposits -= amount;
        emit LoanTaken(msg.sender, amount, interestRate, duration);
    }

    function repayLoan(uint256 loanIndex) external payable {
        Loan storage loan = loans[msg.sender][loanIndex];
        require(!loan.repaid, "Loan already repaid");
        require(block.timestamp < loan.startTime + loan.duration, "Loan duration has ended");

        uint256 interest = (loan.amount * loan.interestRate * loan.duration) / (10000 * 365 * 24 * 60 * 60);
        uint256 totalRepayment = loan.amount + interest;
        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        loan.repaid = true;
        totalDeposits += totalRepayment;
        emit LoanRepaid(msg.sender, totalRepayment);
    }

    function getLoans(address borrower) external view returns (Loan[] memory) {
        return loans[borrower];
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}