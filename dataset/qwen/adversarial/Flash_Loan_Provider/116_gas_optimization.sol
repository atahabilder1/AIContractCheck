// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFlashLoanReceiver {
    function executeOperation(address token, uint256 amount, uint256 fee, bytes calldata params) external returns (bool);
}

contract FlashLoanProvider {
    mapping(address => uint256) public balances;

    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        balances[token] += amount;
    }

    function flashLoan(address token, uint256 amount, address receiver, bytes calldata params) external {
        uint256 balanceBefore = balances[token];
        require(balanceBefore >= amount, "Insufficient balance");

        balances[token] -= amount;
        uint256 fee = amount * 5 / 1000; // 0.5% fee
        bool success = IFlashLoanReceiver(receiver).executeOperation(token, amount, fee, params);

        require(success, "Flash loan failed");
        require(balances[token] >= balanceBefore + fee, "Flash loan not repaid");
    }
}