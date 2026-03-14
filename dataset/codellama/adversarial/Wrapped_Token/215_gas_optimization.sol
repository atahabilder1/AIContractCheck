// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WrappedToken {
    address private _owner;
    mapping(address => uint) private _balances;
    uint private _totalSupply;

    constructor(address owner) public {
        _owner = owner;
        _totalSupply = 100000000;
    }

    function balanceOf(address account) public view returns (uint) {
        return _balances[account];
    }

    function transfer(address recipient, uint amount) public {
        require(msg.sender == _owner, "Only the owner can transfer");
        require(amount > 0, "Invalid amount");
        require(_totalSupply >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
    }
}