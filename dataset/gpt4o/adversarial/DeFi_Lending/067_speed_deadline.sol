// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiLending {
    address public owner;
    mapping(address => uint256) public depositedEther;
    mapping(address => uint256) public borrowedEther;
    uint256 public interestRate = 5; // 5% interest rate

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit value must be greater than zero");
        depositedEther[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(depositedEther[msg.sender] >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Contract balance low");

        depositedEther[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(depositedEther[msg.sender] >= amount / 2, "Collateral must be at least 50% of loan");
        
        borrowedEther[msg.sender] += amount;
        payable(msg.sender).transfer(amount);
        emit Borrow(msg.sender, amount);
    }

    function repay() external payable {
        uint256 debtWithInterest = borrowedEther[msg.sender] + (borrowedEther[msg.sender] * interestRate / 100);
        require(msg.value == debtWithInterest, "Repay amount must cover the debt with interest");

        borrowedEther[msg.sender] = 0;
        emit Repay(msg.sender, msg.value);
    }

    function setInterestRate(uint256 newRate) external onlyOwner {
        interestRate = newRate;
    }

    receive() external payable {}
}