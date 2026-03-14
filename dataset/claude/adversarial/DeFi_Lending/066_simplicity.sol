// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleLending {
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public borrows;

    uint256 public totalDeposits;
    uint256 public totalBorrows;

    uint256 public constant COLLATERAL_FACTOR = 75; // 75% LTV

    function deposit() external payable {
        require(msg.value > 0, "Must deposit ETH");
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient deposits");
        uint256 locked = (borrows[msg.sender] * 100) / COLLATERAL_FACTOR;
        require(deposits[msg.sender] - amount >= locked, "Collateral locked");
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        payable(msg.sender).transfer(amount);
    }

    function borrow(uint256 amount) external {
        uint256 maxBorrow = (deposits[msg.sender] * COLLATERAL_FACTOR) / 100;
        require(borrows[msg.sender] + amount <= maxBorrow, "Exceeds collateral");
        require(address(this).balance >= amount, "Insufficient liquidity");
        borrows[msg.sender] += amount;
        totalBorrows += amount;
        payable(msg.sender).transfer(amount);
    }

    function repay() external payable {
        require(msg.value > 0, "Must repay ETH");
        require(borrows[msg.sender] >= msg.value, "Overpayment");
        borrows[msg.sender] -= msg.value;
        totalBorrows -= msg.value;
    }

    function getMaxBorrow(address user) external view returns (uint256) {
        uint256 maxBorrow = (deposits[user] * COLLATERAL_FACTOR) / 100;
        if (maxBorrow <= borrows[user]) return 0;
        return maxBorrow - borrows[user];
    }
}