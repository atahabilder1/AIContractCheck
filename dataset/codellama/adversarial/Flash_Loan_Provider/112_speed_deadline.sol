// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    address public owner;
    mapping(address => uint) public balances;
    mapping(address => uint) public totalFlashLoans;

    constructor() {
        owner = msg.sender;
    }

    function flashLoan(address _borrower, uint _amount) external {
        require(msg.sender == owner, "Only the owner can call this function");
        require(_amount > 0, "Invalid amount");
        require(balances[_borrower] >= _amount, "Insufficient funds");

        balances[_borrower] -= _amount;
        totalFlashLoans[_borrower] += 1;

        emit FlashLoan(_borrower, _amount);
    }

    function repayLoan(address _borrower, uint _amount) external {
        require(msg.sender == owner, "Only the owner can call this function");
        require(_amount > 0, "Invalid amount");
        require(balances[_borrower] >= _amount, "Insufficient funds");

        balances[_borrower] += _amount;
        totalFlashLoans[_borrower] -= 1;

        emit RepayLoan(_borrower, _amount);
    }

    event FlashLoan(address indexed _borrower, uint _amount);
    event RepayLoan(address indexed _borrower, uint _amount);
}