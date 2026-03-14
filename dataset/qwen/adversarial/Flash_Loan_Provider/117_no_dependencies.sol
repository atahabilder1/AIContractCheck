// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    mapping(address => uint256) public balances;

    event FlashLoanExecuted(address indexed borrower, uint256 amount);

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function flashLoan(address borrower, uint256 amount) external {
        require(balances[address(this)] >= amount, "Insufficient funds in the pool");

        uint256 fee = amount * 5 / 1000; // 0.5% fee
        uint256 amountToRepay = amount + fee;

        balances[borrower] += amount;
        (bool success, ) = borrower.call{value: amount}("");
        require(success, "Flash loan execution failed");

        require(balances[borrower] >= amountToRepay, "Flash loan repayment failed");
        balances[borrower] -= amountToRepay;
        balances[address(this)] += amountToRepay;

        emit FlashLoanExecuted(borrower, amount);
    }
}