// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SimpleLending {
    mapping(address => uint256) public balances;
    uint256 public totalLent;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalLent += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        totalLent -= amount;
        payable(msg.sender).transfer(amount);
    }
}