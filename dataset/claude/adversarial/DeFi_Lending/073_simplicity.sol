// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DeFiLending {
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public borrows;
    mapping(address => uint256) public borrowTimestamp;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public constant COLLATERAL_FACTOR = 75; // 75%
    uint256 public constant INTEREST_RATE_PER_SECOND = 317097920; // ~1% per year in wei-like precision
    uint256 public constant RATE_PRECISION = 1e18;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Zero deposit");
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient deposit");
        uint256 locked = borrows[msg.sender] * 100 / COLLATERAL_FACTOR;
        require(deposits[msg.sender] - amount >= locked, "Collateral locked");
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        uint256 maxBorrow = deposits[msg.sender] * COLLATERAL_FACTOR / 100;
        uint256 outstanding = getDebt(msg.sender);
        require(outstanding + amount <= maxBorrow, "Exceeds collateral");
        require(address(this).balance >= amount, "Insufficient liquidity");

        if (borrows[msg.sender] > 0) {
            borrows[msg.sender] = outstanding;
        }
        borrows[msg.sender] += amount;
        borrowTimestamp[msg.sender] = block.timestamp;
        totalBorrows += amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        emit Borrow(msg.sender, amount);
    }

    function repay() external payable {
        uint256 debt = getDebt(msg.sender);
        require(debt > 0, "No debt");
        uint256 payment = msg.value > debt ? debt : msg.value;

        borrows[msg.sender] = debt - payment;
        borrowTimestamp[msg.sender] = block.timestamp;
        totalBorrows = totalBorrows > payment ? totalBorrows - payment : 0;

        if (msg.value > debt) {
            (bool success, ) = msg.sender.call{value: msg.value - debt}("");
            require(success, "Refund failed");
        }
        emit Repay(msg.sender, payment);
    }

    function liquidate(address borrower) external payable {
        uint256 debt = getDebt(borrower);
        uint256 maxBorrow = deposits[borrower] * COLLATERAL_FACTOR / 100;
        require(debt > maxBorrow, "Not liquidatable");
        require(msg.value >= debt, "Insufficient repayment");

        uint256 collateral = deposits[borrower];
        deposits[borrower] = 0;
        borrows[borrower] = 0;
        borrowTimestamp[borrower] = 0;
        totalDeposits -= collateral;
        totalBorrows = totalBorrows > debt ? totalBorrows - debt : 0;

        uint256 refund = msg.value - debt;
        uint256 reward = collateral + refund;
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Transfer failed");
        emit Liquidate(msg.sender, borrower, debt);
    }

    function getDebt(address user) public view returns (uint256) {
        if (borrows[user] == 0) return 0;
        uint256 elapsed = block.timestamp - borrowTimestamp[user];
        uint256 interest = borrows[user] * INTEREST_RATE_PER_SECOND * elapsed / RATE_PRECISION;
        return borrows[user] + interest;
    }
}