// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GasOptimizedLending {
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _borrowed;
    uint256 private _totalLiquidity;

    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        _balances[msg.sender] += msg.value;
        _totalLiquidity += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function borrow(uint256 amount) external {
        require(amount > 0 && amount <= _totalLiquidity, "Invalid borrow amount");
        _borrowed[msg.sender] += amount;
        _totalLiquidity -= amount;
        payable(msg.sender).transfer(amount);
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0 && _borrowed[msg.sender] >= amount, "Invalid repayment amount");
        _borrowed[msg.sender] -= amount;
        _totalLiquidity += amount;
        emit Repay(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0 && _balances[msg.sender] >= amount, "Invalid withdrawal amount");
        _balances[msg.sender] -= amount;
        _totalLiquidity -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    function borrowedOf(address user) external view returns (uint256) {
        return _borrowed[user];
    }

    function totalLiquidity() external view returns (uint256) {
        return _totalLiquidity;
    }
}