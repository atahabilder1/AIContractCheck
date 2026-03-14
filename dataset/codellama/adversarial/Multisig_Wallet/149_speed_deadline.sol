// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address private _owner;
    mapping(address => uint) private _balances;
    uint private _threshold;

    event Deposit(address indexed from, uint value);
    event Withdrawal(address indexed to, uint value);

    constructor(address owner, uint threshold) public {
        _owner = owner;
        _threshold = threshold;
    }

    function deposit() public payable {
        require(msg.sender == _owner, "Only the owner can deposit");
        _balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint amount) public {
        require(msg.sender == _owner, "Only the owner can withdraw");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        require(_threshold <= amount, "Withdrawal amount must be greater than or equal to the threshold");
        _balances[msg.sender] -= amount;
        emit Withdrawal(msg.sender, amount);
    }

    function getBalance() public view returns (uint) {
        return _balances[msg.sender];
    }

    function getThreshold() public view returns (uint) {
        return _threshold;
    }
}