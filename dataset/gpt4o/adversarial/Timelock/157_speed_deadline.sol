// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public owner;
    uint256 public unlockTime;

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed receiver, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier lockExpired() {
        require(block.timestamp >= unlockTime, "Lock not expired");
        _;
    }

    constructor(uint256 _durationInSeconds) {
        owner = msg.sender;
        unlockTime = block.timestamp + _durationInSeconds;
    }

    function deposit() external payable onlyOwner {
        require(msg.value > 0, "No ether deposited");
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw() external onlyOwner lockExpired {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
        emit Withdrawn(owner, balance);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}