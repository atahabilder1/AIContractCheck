// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

interface ILiquidityPool {
    function flashLoan(uint256 amount) external;
    function returnFunds(uint256 amount) external;
}

interface IInterestRateModel {
    function getInterestRate(uint256 utilizationRate) external view returns (uint256);
}

contract LendingProtocol {
    IERC20 public immutable dai;
    ILiquidityPool public immutable pool;
    IInterestRateModel public immutable interestRateModel;

    struct Loan {
        address borrower;
        uint256 amount;
        uint256 collateralValue;
        uint256 interestRate;
        uint256 start;
        uint256 duration;
    }

    mapping(address => Loan) public loans;

    event LoanCreated(address indexed borrower, uint256 amount, uint256 duration);
    event LoanRepaid(address indexed borrower, uint256 amount);
    event LoanLiquidated(address indexed borrower, uint256 amount, address liquidator);

    constructor(address _dai, address _pool, address _interestRateModel) {
        dai = IERC20(_dai);
        pool = ILiquidityPool(_pool);
        interestRateModel = IInterestRateModel(_interestRateModel);
    }

    function createLoan(uint256 amount, uint256 duration) external {
        require(amount > 0, "Amount must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");

        dai.transferFrom(msg.sender, address(this), amount);

        Loan storage loan = loans[msg.sender];
        loan.borrower = msg.sender;
        loan.amount = amount;
        loan.start = block.timestamp;
        loan.duration = duration;
        loan.interestRate = interestRateModel.getInterestRate(calculateUtilizationRate(amount));

        emit LoanCreated(msg.sender, amount, duration);
    }

    function repayLoan(uint256 amount) external {
        Loan storage loan = loans[msg.sender];
        require(loan.borrower == msg.sender, "Only the borrower can repay the loan");
        require(amount >= loan.amount, "Repayment amount must be at least the loan amount");

        uint256 remainingDebt = loan.amount + calculateInterest(loan.amount, loan.interestRate, block.timestamp - loan.start);
        require(dai.balanceOf(address(this)) >= remainingDebt, "Insufficient balance to repay the loan");

        dai.transfer(msg.sender, amount);
        loan.borrower = address(0);

        emit LoanRepaid(msg.sender, amount);
    }

    function liquidateLoan(address borrower) external {
        Loan storage loan = loans[borrower];
        require(loan.borrower != address(0), "Loan does not exist or is already repaid");
        require(block.timestamp >= loan.start + loan.duration, "Loan is not yet due for liquidation");
        require(dai.balanceOf(address(this)) >= loan.amount, "Insufficient balance to cover the loan");

        uint256 liquidationBonus = 0; // Define liquidation bonus logic
        uint256 liquidationAmount = loan.amount + calculateInterest(loan.amount, loan.interestRate, block.timestamp - loan.start) + liquidationBonus;

        dai.transfer(msg.sender, liquidationAmount);
        loan.borrower = address(0);

        emit LoanLiquidated(borrower, loan.amount, msg.sender);
    }

    function calculateUtilizationRate(uint256 loanAmount) public view returns (uint256) {
        uint256 totalCollateralValue = dai.balanceOf(address(this));
        return loanAmount * 100 / totalCollateralValue;
    }

    function calculateInterest(uint256 principal, uint256 rate, uint256 timeElapsed) public pure returns (uint256) {
        return principal * rate * timeElapsed / (365 days);
    }
}