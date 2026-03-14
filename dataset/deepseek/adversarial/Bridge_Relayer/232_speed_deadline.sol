// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract BridgeRelayer {
    address public owner;
    mapping(address => bool) public approvedTokens;
    mapping(address => mapping(address => uint256)) public deposits;

    event Deposit(address token, address user, uint256 amount);
    event Withdraw(address token, address user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function approveToken(address token) public onlyOwner {
        approvedTokens[token] = true;
    }

    function deposit(address token, uint256 amount) public {
        require(approvedTokens[token], "Token not approved");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        deposits[token][msg.sender] += amount;
        emit Deposit(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) public {
        require(deposits[token][msg.sender] >= amount, "Insufficient balance");
        deposits[token][msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit Withdraw(token, msg.sender, amount);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}