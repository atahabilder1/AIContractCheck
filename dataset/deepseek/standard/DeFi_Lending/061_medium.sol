// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LendingProtocol {
    IERC20 public immutable token;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    struct Loan {
        uint256 amount;
        uint256 interestRate;
        uint256 startTimestamp;
        uint256 duration;
    }

    mapping(address => Loan) public loans;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function borrow(uint256 amount, uint256 interestRate, uint256 duration) external {
        require(interestRate > 0, "Interest rate must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");

        loans[msg.sender] = Loan({
            amount: amount,
            interestRate: interestRate,
            startTimestamp: block.timestamp,
            duration: duration
        });

        token.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        Loan storage loan = loans[msg.sender];
        require(loan.amount > 0, "No loan found");

        uint256 repayAmount = amount;
        if (block.timestamp > loan.startTimestamp + loan.duration) {
            uint256 lateFee = loan.amount * loan.interestRate / 100;
            repayAmount += lateFee;
        }

        require(token.transferFrom(msg.sender, address(this), repayAmount), "Repayment transfer failed");
        if (block.timestamp > loan.startTimestamp + loan.duration) {
            loan.interestRate += lateFee;
        }
        loan.amount -= amount;
    }

    function liquidate(address borrower) external {
        Loan storage loan = loans[borrower];
        require(loan.amount > 0, "No loan found");
        require(getHealthFactor(borrower) < MIN_HEALTH_FACTOR, "Health factor is not low enough");

        uint256 liquidationAmount = loan.amount;
        token.transfer(msg.sender, liquidationAmount);
        delete loans[borrower];
    }

    function getHealthFactor(address borrower) public view returns (uint256) {
        Loan memory loan = loans[borrower];
        if (loan.amount == 0) {
            return MIN_HEALTH_FACTOR;
        }

        uint256 borrowedAmount = loan.amount;
        uint256 collateralValue = token.balanceOf(borrower);
        uint256 healthFactor = (collateralValue * 1e18) / borrowedAmount;
        return healthFactor;
    }
}