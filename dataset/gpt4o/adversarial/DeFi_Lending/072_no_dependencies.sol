// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interest;
        uint256 dueDate;
        bool repaid;
    }

    uint256 public interestRate = 5; // 5% interest
    uint256 public loanDuration = 30 days;
    
    mapping(address => uint256) public balances;
    mapping(address => Loan[]) public loans;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event LoanTaken(address indexed borrower, uint256 amount, uint256 interest, uint256 dueDate);
    event LoanRepaid(address indexed borrower, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function takeLoan(uint256 amount) external {
        require(balances[address(this)] >= amount, "Insufficient pool balance");
        
        uint256 interest = calculateInterest(amount);
        uint256 dueDate = block.timestamp + loanDuration;

        loans[msg.sender].push(Loan({
            borrower: msg.sender,
            amount: amount,
            interest: interest,
            dueDate: dueDate,
            repaid: false
        }));

        balances[address(this)] -= amount;
        payable(msg.sender).transfer(amount);

        emit LoanTaken(msg.sender, amount, interest, dueDate);
    }

    function repayLoan(uint256 loanIndex) external payable {
        Loan storage loan = loans[msg.sender][loanIndex];
        require(!loan.repaid, "Loan already repaid");
        require(msg.value >= loan.amount + loan.interest, "Repayment amount insufficient");
        require(block.timestamp <= loan.dueDate, "Loan is overdue");

        loan.repaid = true;
        balances[address(this)] += msg.value;

        emit LoanRepaid(msg.sender, msg.value);
    }

    function calculateInterest(uint256 amount) internal view returns (uint256) {
        return (amount * interestRate) / 100;
    }

    function getLoans(address borrower) external view returns (Loan[] memory) {
        return loans[borrower];
    }
}