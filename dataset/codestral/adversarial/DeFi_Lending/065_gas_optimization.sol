// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DefiLending {
    using SafeMath for uint256;

    IERC20 public token;
    mapping(address => uint) public balances;
    mapping(address => uint) public borrowedBalances;
    mapping(address => bool) public isBorrower;

    constructor(IERC20 _token) {
        token = _token;
    }

    function deposit(uint amount) external {
        require(amount > 0, "Amount must be greater than zero");
        balances[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function borrow(uint amount) external {
        uint available = balances[msg.sender];
        require(available > 0 && amount <= available, "Insufficient balance or borrow amount");
        isBorrower[msg.sender] = true;
        borrowedBalances[msg.sender] += amount;
        token.transfer(msg.sender, amount);
    }

    function repay(uint amount) external {
        require(isBorrower[msg.sender], "Not a borrower");
        require(amount > 0 && amount <= borrowedBalances[msg.sender], "Invalid repay amount");
        token.transferFrom(msg.sender, address(this), amount);
        borrowedBalances[msg.sender] -= amount;
        if (borrowedBalances[msg.sender] == 0) {
            isBorrower[msg.sender] = false;
        }
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction underflow");
        return a - b;
    }
}