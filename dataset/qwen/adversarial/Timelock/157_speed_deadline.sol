// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public owner;
    uint256 public unlockTime;
    mapping(bytes32 => bool) public executed;

    constructor(uint256 _unlockTime) {
        require(_unlockTime > block.timestamp, "Unlock time must be in the future");
        owner = msg.sender;
        unlockTime = _unlockTime;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAfterUnlock() {
        require(block.timestamp > unlockTime, "Time lock has not expired yet");
        _;
    }

    function executeTransaction(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner onlyAfterUnlock returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(_target, _value, _data));
        require(!executed[txHash], "Transaction already executed");

        (bool success, bytes memory data) = _target.call{value: _value}(_data);
        require(success, "Transaction execution failed");

        executed[txHash] = true;

        return data;
    }
}