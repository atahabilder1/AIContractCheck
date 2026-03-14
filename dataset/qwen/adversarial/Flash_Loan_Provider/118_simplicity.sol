// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanReceiver {
    function executeOperation(address token, uint256 amount, uint256 fee, bytes calldata params) external returns (bool);
}

contract FlashLoanProvider {
    mapping(address => uint256) public balances;

    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Deposit amount must be greater than zero");
        balances[token] += amount;
    }

    function flashLoan(address token, uint256 amount, address receiver, bytes calldata params) external {
        uint256 fee = amount * 5 / 1000; // 0.5% fee
        require(balances[token] >= amount + fee, "Insufficient balance");

        balances[token] -= amount;
        bool success = IFlashLoanReceiver(receiver).executeOperation(token, amount, fee, params);
        require(success, "Flash loan execution failed");

        balances[token] += amount + fee;
    }
}