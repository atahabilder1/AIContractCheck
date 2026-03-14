// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStableCoin {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CollateralizedLending {
    IStableCoin public stableCoin;
    uint256 public collateralizationRatio = 150; // 150%
    uint256 public interestRate = 5; // 5% annual
    uint256 public constant SECONDS_IN_A_YEAR = 31536000;

    struct Loan {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 interestAccumulated;
        uint256 lastInterestCalculation;
    }

    mapping(address => Loan) public loans;

    constructor(address _stableCoinAddress) {
        stableCoin = IStableCoin(_stableCoinAddress);
    }

    function depositCollateral() external payable {
        Loan storage loan = loans[msg.sender];
        loan.collateralAmount += msg.value;
    }

    function borrow(uint256 _borrowAmount) external {
        Loan storage loan = loans[msg.sender];
        require(_borrowAmount > 0, "Borrow amount must be greater than zero");
        require(loan.collateralAmount > 0, "No collateral deposited");

        uint256 maxBorrow = (loan.collateralAmount * (100 / collateralizationRatio)) / 100 ether;
        require(_borrowAmount <= maxBorrow, "Exceeds maximum borrowable amount");

        updateInterest(msg.sender);
        loan.borrowedAmount += _borrowAmount;
        stableCoin.transfer(msg.sender, _borrowAmount);
    }

    function repay(uint256 _repayAmount) external {
        Loan storage loan = loans[msg.sender];
        require(_repayAmount > 0, "Repay amount must be greater than zero");
        require(loan.borrowedAmount > 0, "No active loan");

        updateInterest(msg.sender);
        uint256 totalOwed = loan.borrowedAmount + loan.interestAccumulated;
        require(_repayAmount <= totalOwed, "Repay amount exceeds total owed");

        stableCoin.transferFrom(msg.sender, address(this), _repayAmount);
        if (_repayAmount >= loan.interestAccumulated) {
            loan.borrowedAmount -= (_repayAmount - loan.interestAccumulated);
            loan.interestAccumulated = 0;
        } else {
            loan.interestAccumulated -= _repayAmount;
        }
    }

    function withdrawCollateral(uint256 _withdrawAmount) external {
        Loan storage loan = loans[msg.sender];
        require(_withdrawAmount > 0, "Withdraw amount must be greater than zero");
        require(loan.collateralAmount >= _withdrawAmount, "Insufficient collateral");

        updateInterest(msg.sender);
        uint256 maxBorrow = (loan.collateralAmount * (100 / collateralizationRatio)) / 100 ether;
        uint256 totalOwed = loan.borrowedAmount + loan.interestAccumulated;
        require(totalOwed <= maxBorrow, "Cannot withdraw while undercollateralized");

        loan.collateralAmount -= _withdrawAmount;
        payable(msg.sender).transfer(_withdrawAmount);
    }

    function updateInterest(address _borrower) internal {
        Loan storage loan = loans[_borrower];
        uint256 timeElapsed = block.timestamp - loan.lastInterestCalculation;
        uint256 interest = (loan.borrowedAmount * interestRate * timeElapsed) / SECONDS_IN_A_YEAR / 100;
        loan.interestAccumulated += interest;
        loan.lastInterestCalculation = block.timestamp;
    }

    function getLoanDetails(address _borrower) external view returns (uint256 collateral, uint256 borrowed, uint256 interest) {
        Loan storage loan = loans[_borrower];
        return (loan.collateralAmount, loan.borrowedAmount, loan.interestAccumulated);
    }
}