// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract LendingProtocol {
    struct User {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 borrowTimestamp;
    }

    mapping(address => User) public users;
    uint256 public collateralFactor = 80; // 80%
    uint256 public liquidationThreshold = 70; // 70%
    uint256 public baseInterestRate = 5; // 5% per year
    uint256 public interestRateSlope = 1; // 1% increase per year for each 10% borrowed over 50%
    uint256 public collateralPrice = 1000; // Price of collateral in USD
    uint256 public loanPrice = 100; // Price of loan in USD

    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed user, uint256 collateralAmount);

    function depositCollateral(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        users[msg.sender].collateralAmount += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function borrow(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(canBorrow(msg.sender, _amount), "Cannot borrow more than allowed");

        users[msg.sender].borrowedAmount += _amount;
        users[msg.sender].borrowTimestamp = block.timestamp;
        emit Borrow(msg.sender, _amount);
    }

    function repay(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(users[msg.sender].borrowedAmount >= _amount, "Not enough borrowed amount");

        users[msg.sender].borrowedAmount -= _amount;
        emit Repay(msg.sender, _amount);
    }

    function liquidate(address _user) external {
        require(isLiquidatable(_user), "User is not liquidatable");
        uint256 collateralToLiquidate = users[_user].collateralAmount;
        users[_user].collateralAmount = 0;
        users[_user].borrowedAmount = 0;
        emit Liquidate(_user, collateralToLiquidate);
    }

    function canBorrow(address _user, uint256 _amount) internal view returns (bool) {
        uint256 newBorrowedAmount = users[_user].borrowedAmount + _amount;
        uint256 healthFactor = calculateHealthFactor(_user, newBorrowedAmount);
        return healthFactor >= liquidationThreshold;
    }

    function isLiquidatable(address _user) internal view returns (bool) {
        uint256 healthFactor = calculateHealthFactor(_user, users[_user].borrowedAmount);
        return healthFactor < liquidationThreshold;
    }

    function calculateHealthFactor(address _user, uint256 _borrowedAmount) internal view returns (uint256) {
        uint256 collateralValue = users[_user].collateralAmount * collateralPrice;
        uint256 borrowedValue = _borrowedAmount * loanPrice;
        uint256 interestAccrued = calculateInterest(_borrowedAmount);
        uint256 totalDebt = borrowedValue + interestAccrued;

        if (totalDebt == 0) {
            return type(uint256).max;
        }

        return (collateralValue * collateralFactor) / totalDebt;
    }

    function calculateInterest(uint256 _borrowedAmount) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - users[msg.sender].borrowTimestamp;
        uint256 interestRate = baseInterestRate + ((interestRateSlope * _borrowedAmount) / 100);
        uint256 interestAccrued = (_borrowedAmount * interestRate * timeElapsed) / (365 days * 100);
        return interestAccrued;
    }
}