// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WrappedToken {
    string public name = "Wrapped Token";
    string public symbol = "WTOKEN";
    uint8 public decimals = 18;

    mapping(address => uint256) public balances;

    constructor() {}

    function deposit(uint256 amount) external {
        balances[msg.sender] += amount * (10 ** uint256(decimals));
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
    }

    function transfer(address recipient, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }
}