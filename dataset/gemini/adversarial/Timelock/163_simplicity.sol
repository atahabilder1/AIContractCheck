// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    mapping(address => uint256) public releaseTimes;

    event LogRefund(address indexed user, uint256 amount);
    event LogDeposit(address indexed user, uint256 amount);

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than zero.");
        emit LogDeposit(msg.sender, msg.value);
    }

    function setReleaseTime(uint256 _releaseTime) public {
        releaseTimes[msg.sender] = _releaseTime;
    }

    function release() public {
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds to release.");
        require(block.timestamp >= releaseTimes[msg.sender], "Release time not yet reached.");

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed.");

        emit LogRefund(msg.sender, amount);
    }
}