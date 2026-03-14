// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    mapping(address => uint256) public releaseTimes;
    address public owner;

    event Log(address indexed target, uint256 value, bytes data, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function schedule(address target, uint256 value, bytes calldata data, uint256 timestamp) public onlyOwner {
        require(timestamp >= block.timestamp, "TIMESTAMP_IN_PAST");
        emit Log(target, value, data, timestamp);
    }

    function release(address target, uint256 value, bytes calldata data, uint256 timestamp) public onlyOwner {
        require(timestamp <= block.timestamp, "TIMESTAMP_NOT_MET");
        (bool success, ) = target.call{value: value}(data);
        require(success, "TARGET_CALL_FAILED");
    }

    // Fallback function to receive Ether
    receive() external payable {}
}