// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public timelock;
    uint256 public delay;

    constructor(address _timelock, uint256 _delay) {
        timelock = _timelock;
        delay = _delay;
    }

    modifier timeLock() {
        if (block.timestamp >= _executionTime()) _;
    }

    function execute(address target, bytes calldata data) external timeLock {
        (bool success, ) = target.call(data);
        require(success, "Execution failed");
    }

    function scheduleExecution(uint256 _timestamp) public {
        timelock = msg.sender;
        delay = _timestamp - block.timestamp;
    }

    function cancelExecution() public timeLock {
        timelock = address(0);
    }

    uint256 private _executionTime() view {
        return block.timestamp + delay;
    }
}