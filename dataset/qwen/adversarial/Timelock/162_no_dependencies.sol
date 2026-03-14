// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public owner;
    uint256 public unlockTime;
    mapping(bytes32 => bool) public executed;

    event Deposit(address indexed sender, uint256 amount, uint256 time);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 executionTime);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier notExecuted(bytes32 _txHash) {
        require(!executed[_txHash], "Transaction already executed");
        _;
    }

    modifier lockTimePassed() {
        require(block.timestamp > unlockTime, "Lock time has not yet passed");
        _;
    }

    constructor(uint256 _duration) {
        require(_duration > 0, "Duration must be greater than 0");
        owner = msg.sender;
        unlockTime = block.timestamp + _duration;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    function executeTransaction(
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _data
    ) public payable onlyOwner lockTimePassed {
        bytes32 txHash = getTxHash(_target, _value, _signature, _data);
        require(!executed[txHash], "Transaction already executed");

        bytes memory callData;
        if (bytes(_signature).length == 0) {
            callData = _data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(_signature))), _data);
        }

        (bool success, ) = _target.call{value: _value}(callData);
        require(success, "Transaction failed");

        executed[txHash] = true;

        emit ExecuteTransaction(txHash, _target, _value, _signature, _data, block.timestamp);
    }

    function getTxHash(
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _data
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_target, _value, _signature, _data));
    }
}