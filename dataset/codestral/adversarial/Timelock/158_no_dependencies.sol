// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract Timelock {
    address public executor;
    uint256 public delay;
    mapping(bytes32 => uint256) public timestamps;

    constructor(address _executor, uint256 _delay) {
        executor = _executor;
        delay = _delay;
    }

    function scheduleTransaction(address to, uint value, bytes memory data, uint256 _timestamp) public {
        require(_timestamp >= block.timestamp + delay, "Timelock: Insufficient delay");
        bytes32 txHash = keccak256(abi.encodePacked(to, value, data));
        timestamps[txHash] = _timestamp;
    }

    function executeTransaction(address to, uint value, bytes memory data) public {
        require(msg.sender == executor, "Timelock: Only executor can call this function");
        bytes32 txHash = keccak256(abi.encodePacked(to, value, data));
        require(timestamps[txHash] <= block.timestamp, "Timelock: Transaction hasn't surpassed delay");
        (bool success, ) = to.call{value: value}(data);
        require(success, "Timelock: Transaction execution failed");
    }
}