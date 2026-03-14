// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanReceiver {
    function executeOperation(uint256 amount) external;
}

contract FlashLoanProvider {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function flashLoan(uint256 amount) external {
        require(address(this).balance >= amount, "Insufficient balance in the pool");
        uint256 balanceBefore = address(this).balance;

        IFlashLoanReceiver(msg.sender).executeOperation(amount);

        require(address(this).balance >= balanceBefore, "Flash loan not paid back");
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}