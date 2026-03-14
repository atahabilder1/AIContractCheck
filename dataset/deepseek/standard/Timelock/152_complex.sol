// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract TimelockController is AccessControl {
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;

    struct Operation {
        address target;
        uint256 value;
        bytes data;
        uint256 executionTime;
        bool executed;
        address[] predecessors;
    }

    mapping(uint256 => Operation) public operations;
    uint256 public nextOperationId;

    event NewOperation(uint256 indexed operationId, address indexed target, uint256 value, bytes data, uint256 executionTime);
    event OperationExecuted(uint256 indexed operationId, address indexed target, uint256 value, bytes data, uint256 executionTime);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TIMELOCK_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(TIMELOCK_ADMIN_ROLE, TIMELOCK_ADMIN_ROLE);
    }

    modifier onlyAdmin() {
        require(hasRole(TIMELOCK_ADMIN_ROLE, msg.sender), "TimelockController: caller is not a admin");
        _;
    }

    modifier onlyProposer() {
        require(hasRole(PROPOSER_ROLE, msg.sender), "TimelockController: caller is not a proposer");
        _;
    }

    function setMinDelay(uint256 newMinDelay) external onlyAdmin {
        require(newMinDelay >= MIN_DELAY && newMinDelay <= MAX_DELAY, "TimelockController: delay must be between MIN_DELAY and MAX_DELAY");
        // Implementation of setting min delay
    }

    function proposeOperation(address target, uint256 value, bytes memory data, uint256 executionTime, address[] memory predecessors) public onlyProposer returns (uint256) {
        require(executionTime >= block.timestamp + MIN_DELAY, "TimelockController: execution time must be after minimum delay");
        require(executionTime <= block.timestamp + MAX_DELAY, "TimelockController: execution time must be within maximum delay");
        for (uint256 i = 0; i < predecessors.length; i++) {
            require(operations[predecessors[i]].executed, "TimelockController: predecessor not executed");
        }

        Operation storage newOperation = operations[nextOperationId];
        newOperation.target = target;
        newOperation.value = value;
        newOperation.data = data;
        newOperation.executionTime = executionTime;
        newOperation.executed = false;
        newOperation.predecessors = predecessors;

        emit NewOperation(nextOperationId, target, value, data, executionTime);
        return nextOperationId++;
    }

    function executeOperation(uint256 operationId) external onlyAdmin {
        Operation storage operation = operations[operationId];
        require(block.timestamp >= operation.executionTime, "TimelockController: operation not yet executable");
        require(!operation.executed, "TimelockController: operation already executed");

        (bool success, ) = operation.target.call{value: operation.value}(operation.data);
        require(success, "TimelockController: operation execution failed");

        operation.executed = true;
        emit OperationExecuted(operationId, operation.target, operation.value, operation.data, operation.executionTime);
    }
}