// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    uint256 private constant MIN_DELAY = 1 days;
    address public owner;
    mapping(bytes32 => Task) private tasks;

    struct Task {
        bytes data;
        bool executed;
    }

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function queueTransaction(address target, uint256 value, bytes memory data, uint256 eta) public onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(target, value, data, eta));
        tasks[hash] = Task(data, false);
    }

    function executeTransaction(address target, uint256 value, bytes memory data, uint256 eta) public {
        require(block.timestamp >= eta + MIN_DELAY, "Not enough time has passed");
        bytes32 hash = keccak256(abi.encodePacked(target, value, data, eta));
        Task memory task = tasks[hash];
        require(!task.executed, "Transaction already executed");
        (bool success, ) = target.call{value: value}(data);
        require(success, "Execution failed");
        task.executed = true;
    }
}