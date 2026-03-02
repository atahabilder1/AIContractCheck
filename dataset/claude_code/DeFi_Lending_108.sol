// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic DeFi Lending Contract
contract BasicLending {
    address public collateralToken;
    address public loanToken;
    uint256 public collateralFactor = 75; // 75%
    uint256 public liquidationThreshold = 80; // 80%
    uint256 public interestRate = 5; // 5% per year

    mapping(address => uint256) public collateralDeposits;
    mapping(address => uint256) public borrowedAmounts;
    mapping(address => uint256) public borrowTimestamp;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed user, address indexed liquidator, uint256 amount);

    constructor(address _collateralToken, address _loanToken) {
        collateralToken = _collateralToken;
        loanToken = _loanToken;
    }

    function deposit(uint256 amount) external {
        collateralDeposits[msg.sender] += amount;
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(collateralDeposits[msg.sender] >= amount, "Insufficient collateral");
        require(isSolvent(msg.sender, amount), "Would be insolvent");
        collateralDeposits[msg.sender] -= amount;
        IERC20(collateralToken).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(canBorrow(msg.sender, amount), "Exceeds borrow limit");
        if (borrowedAmounts[msg.sender] > 0) {
            // Add accrued interest
            borrowedAmounts[msg.sender] += accruedInterest(msg.sender);
        }
        borrowedAmounts[msg.sender] += amount;
        borrowTimestamp[msg.sender] = block.timestamp;
        IERC20(loanToken).transfer(msg.sender, amount);
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        uint256 totalOwed = borrowedAmounts[msg.sender] + accruedInterest(msg.sender);
        uint256 repayAmount = amount > totalOwed ? totalOwed : amount;
        borrowedAmounts[msg.sender] = totalOwed - repayAmount;
        borrowTimestamp[msg.sender] = block.timestamp;
        IERC20(loanToken).transferFrom(msg.sender, address(this), repayAmount);
        emit Repay(msg.sender, repayAmount);
    }

    function liquidate(address user) external {
        require(!isSolvent(user, 0), "User is solvent");
        uint256 collateral = collateralDeposits[user];
        uint256 debt = borrowedAmounts[user] + accruedInterest(user);

        collateralDeposits[user] = 0;
        borrowedAmounts[user] = 0;

        IERC20(loanToken).transferFrom(msg.sender, address(this), debt);
        IERC20(collateralToken).transfer(msg.sender, collateral);
        emit Liquidate(user, msg.sender, collateral);
    }

    function canBorrow(address user, uint256 amount) public view returns (bool) {
        uint256 maxBorrow = collateralDeposits[user] * collateralFactor / 100;
        uint256 currentBorrow = borrowedAmounts[user] + accruedInterest(user);
        return currentBorrow + amount <= maxBorrow;
    }

    function isSolvent(address user, uint256 withdrawAmount) public view returns (bool) {
        uint256 collateral = collateralDeposits[user] - withdrawAmount;
        uint256 debt = borrowedAmounts[user] + accruedInterest(user);
        if (debt == 0) return true;
        return collateral * liquidationThreshold / 100 >= debt;
    }

    function accruedInterest(address user) public view returns (uint256) {
        if (borrowedAmounts[user] == 0) return 0;
        uint256 timeElapsed = block.timestamp - borrowTimestamp[user];
        return borrowedAmounts[user] * interestRate * timeElapsed / (365 days * 100);
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
