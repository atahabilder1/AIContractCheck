// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    address public owner;
    mapping(address => uint) public balances;

    constructor() public {
        owner = msg.sender;
    }

    function flashLoan(address recipient, uint amount) external {
        require(msg.sender == owner, "Only the owner can call this function");
        require(balances[recipient] >= amount, "Insufficient funds");

        balances[recipient] -= amount;
        balances[msg.sender] += amount;

        emit FlashLoan(recipient, amount);
    }

    function repayFlashLoan(address recipient, uint amount) external {
        require(msg.sender == owner, "Only the owner can call this function");
        require(balances[msg.sender] >= amount, "Insufficient funds");

        balances[msg.sender] -= amount;
        balances[recipient] += amount;

        emit RepayFlashLoan(recipient, amount);
    }

    event FlashLoan(address recipient, uint amount);
    event RepayFlashLoan(address recipient, uint amount);
}