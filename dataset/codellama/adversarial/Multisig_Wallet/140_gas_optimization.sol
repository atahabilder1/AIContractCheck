// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint256 public threshold;
    uint256 public balance;

    constructor(address[] memory _owners, uint256 _threshold) {
        owners = _owners;
        threshold = _threshold;
        balance = 0;
    }

    function deposit(uint256 amount) public {
        require(msg.sender == owners[msg.sender], "Only owners can deposit");
        require(amount <= address(this).balance, "Insufficient balance");
        balance += amount;
    }

    function withdraw(uint256 amount) public {
        require(msg.sender == owners[msg.sender], "Only owners can withdraw");
        require(amount <= balance, "Insufficient balance");
        msg.sender.transfer(amount);
        balance -= amount;
    }

    function transfer(address to, uint256 amount) public {
        require(msg.sender == owners[msg.sender], "Only owners can transfer");
        require(amount <= balance, "Insufficient balance");
        to.transfer(amount);
        balance -= amount;
    }

    function getBalance() public view returns (uint256) {
        return balance;
    }
}