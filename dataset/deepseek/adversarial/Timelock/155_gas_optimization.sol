// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    // Address of the owner who can execute the transactions
    address public immutable owner;

    // Mapping to store the time when the funds are locked
    mapping(address => uint256) public releaseTimes;

    // Mapping to store the amount of funds locked for each address
    mapping(address => uint256) public lockedAmounts;

    // Event emitted when a transaction is executed
    event ExecuteTransaction(address indexed beneficiary, uint256 amount);

    // Event emitted when a new timelock is set
    event TimelockSet(address indexed beneficiary, uint256 releaseTime, uint256 amount);

    // Constructor to set the owner and initialize the release times and amounts
    constructor(address _owner) {
        owner = _owner;
    }

    // Function to set a new timelock
    function setTimelock(address beneficiary, uint256 releaseTime, uint256 amount) public {
        require(msg.sender == owner, "Only owner can set timelock");
        require(releaseTime > block.timestamp, "Release time must be in the future");

        releaseTimes[beneficiary] = releaseTime;
        lockedAmounts[beneficiary] = amount;

        emit TimelockSet(beneficiary, releaseTime, amount);
    }

    // Function to release the funds to the beneficiary after the release time
    function release(address beneficiary) public {
        require(block.timestamp >= releaseTimes[beneficiary], "Release time not yet reached");
        require(msg.sender == owner, "Only owner can release funds");

        uint256 amount = lockedAmounts[beneficiary];
        lockedAmounts[beneficiary] = 0;

        // Transfer the funds to the beneficiary
        (bool success, ) = beneficiary.call{value: amount}("");
        require(success, "Transfer failed");

        emit ExecuteTransaction(beneficiary, amount);
    }
}