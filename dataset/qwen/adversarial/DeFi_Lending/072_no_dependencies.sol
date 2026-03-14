// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SimpleLending {
    address public owner;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public loans;
    uint256 public interestRate; // Interest rate in percentage

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);

    constructor(uint256 _interestRate) {
        owner = msg.sender;
        interestRate = _interestRate; // Interest rate set in percentage
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        deposits[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external {
        require(deposits[msg.sender] >= _amount, "Insufficient balance");
        deposits[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit Withdraw(msg.sender, _amount);
    }

    function borrow(uint256 _amount) external {
        require(deposits[msg.sender] >= _amount, "Insufficient collateral");
        require(loans[msg.sender] == 0, "Already have an active loan");
        loans[msg.sender] = _amount;
        payable(msg.sender).transfer(_amount);
        emit Borrow(msg.sender, _amount);
    }

    function repay() external payable {
        require(loans[msg.sender] > 0, "No loan to repay");
        uint256 totalRepayment = loans[msg.sender] + (loans[msg.sender] * interestRate / 100);
        require(msg.value >= totalRepayment, "Insufficient repayment amount");
        loans[msg.sender] = 0;
        deposits[msg.sender] -= totalRepayment;
        emit Repay(msg.sender, totalRepayment);
    }

    function changeInterestRate(uint256 _newRate) external onlyOwner {
        interestRate = _newRate;
    }

    receive() external payable {}
}