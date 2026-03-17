// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Structs.sol";

contract TimelockController is Ownable, EIP712 {
    using SafeMath for uint256;
    using Structs for uint256[];

    enum OperationType {
        Call,
        DelegateCall
    }

    struct QueuedTransaction {
        address target;
        uint value;
        bytes data;
        OperationType operationType;
        uint eta; // Execution Time - Unix timestamp
        bool executed;
    }

    mapping(bytes32 => QueuedTransaction) queuedTransactions;
    mapping(address => mapping(address => bool)) grantedRoles;
    uint minimumDelay;

    constructor(uint _minimumDelay, address[] memory initialProposers, address[] memory initialExecutors) {
        minimumDelay = _minimumDelay;
        for (uint i = 0; i < initialProposers.length; i++) {
            grantRole(hash("PROPOSER_ROLE"), initialProposers[i]);
        }
        for (uint i = 0; i < initialExecutors.length; i++) {
            grantRole(hash("EXECUTOR_ROLE"), initialExecutors[i]);
        }
    }

    bytes32 keccak256(bytes memory _data) internal pure returns (bytes32) {
        return keccak256(_data);
    }

    function hashOperation(QueuedTransaction calldata operation, bytes32 predecessor) private view returns (bytes32) {
        return keccak256(abi.encode(operation, predecessor));
    }

    modifier onlyProposer() {
        require(hasRole(hash("PROPOSER_ROLE"), _msgSender()), "TimelockController: Caller must be a proposer");
        _;
    }

    function queueTransaction(address target, uint256 value, bytes memory data, OperationType operationType, bytes32 predecessor) public onlyProposer {
        QueuedTransaction memory newOperation = QueuedTransaction({
            target: target,
            value: value,
            data: data,
            operationType: operationType,
            eta: block.timestamp.add(minimumDelay),
            executed: false
        });
        bytes32 hash = hashOperation(newOperation, predecessor);
        queuedTransactions[hash] = newOperation;
    }

    modifier onlyExecutor() {
        require(hasRole(hash("EXECUTOR_ROLE"), _msgSender()), "TimelockController: Caller must be an executor");
        _;
    }

    function executeTransaction(address target, uint256 value, bytes memory data, OperationType operationType, bytes32 predecessor) public onlyExecutor {
        QueuedTransaction storage operation = queuedTransactions[hashOperation(QueuedTransaction({
            target: target,
            value: value,
            data: data,
            operationType: operationType,
            eta: 0, // ETA is ignored for execution
            executed: false
        }), predecessor)];
        require(!operation.executed && operation.eta <= block.timestamp, "TimelockController: Transaction cannot be executed");
        if (operation.operationType == OperationType.Call) {
            (bool success, ) = target.call{value: value}(data);
            require(success, "TimelockController: Call failed");
        } else {
            (bool success, ) = address(target).delegatecall(data);
            require(success, "TimelockController: DelegateCall failed");
        }
        operation.executed = true;
    }
}