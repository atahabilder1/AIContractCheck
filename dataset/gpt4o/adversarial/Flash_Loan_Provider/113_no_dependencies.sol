// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    address public owner;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event FlashLoan(address indexed borrower, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier hasSufficientBalance(uint256 amount) {
        require(balances[address(this)] >= amount, "Insufficient balance in pool");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "Must deposit more than 0");
        balances[address(this)] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(balances[address(this)] >= amount, "Insufficient balance in pool");
        balances[address(this)] -= amount;
        payable(owner).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function executeFlashLoan(uint256 amount, address target, bytes calldata data) external hasSufficientBalance(amount) {
        uint256 initialBalance = address(this).balance;

        // Transfer the amount to the borrower
        balances[address(this)] -= amount;
        payable(target).transfer(amount);

        // Emit flash loan event
        emit FlashLoan(target, amount);

        // Execute the operation
        (bool success, ) = target.call(data);
        require(success, "External call failed");

        // Ensure the loan is returned
        require(address(this).balance >= initialBalance, "Flash loan not returned");

        // Update the balance
        balances[address(this)] = address(this).balance;
    }

    receive() external payable {
        balances[address(this)] += msg.value;
    }
}