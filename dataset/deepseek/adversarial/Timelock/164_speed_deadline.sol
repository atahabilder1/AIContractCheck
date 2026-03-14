// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(block.timestamp >= unlockTime[msg.sender], "Lock time not reached");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    mapping(address => uint256) public unlockTime;

    function scheduleWithdrawal(uint256 delay) public {
        unlockTime[msg.sender] = block.timestamp + delay;
    }
}