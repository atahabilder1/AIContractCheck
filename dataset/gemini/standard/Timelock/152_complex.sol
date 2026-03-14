// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title TimelockController
 * @dev A contract that allows an administrator to schedule operations and execute them
 * after a configurable delay. Operations can be executed by a designated executor role.
 *
 * Features:
 * - Role-based scheduling: Operations can only be scheduled by users with the SCHEDULER_ROLE.
 * - Minimum delay enforcement: Operations can only be executed after a minimum delay has passed.
 * - Operation batching: Multiple operations can be scheduled and executed together.
 * - Predecessor dependencies: An operation can depend on the successful execution of a previous operation.
 */
contract TimelockController is AccessControl {
    bytes32 public constant SCHEDULER_ROLE = keccak256("SCHEDULER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    struct Operation {
        address target;
        bytes data;
        uint256 eta; // Estimated Time of Arrival
        uint256 predecessor; // Index of the predecessor operation, 0 means no predecessor
        bool executed;
        bool cancelled;
    }

    Operation[] public operations;
    uint256 public minDelay;
    uint256 public lastExecutedTimestamp;

    event OperationScheduled(
        uint256 indexed id,
        address target,
        bytes data,
        uint256 eta,
        uint256 predecessor
    );
    event OperationExecuted(uint256 indexed id);
    event OperationCancelled(uint256 indexed id);
    event MinDelayChanged(uint256 newMinDelay);

    /**
     * @dev Initializes the contract with a minimum delay.
     * @param initialMinDelay The initial minimum delay in seconds.
     */
    constructor(uint256 initialMinDelay) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SCHEDULER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(CANCELLER_ROLE, msg.sender);
        minDelay = initialMinDelay;
    }

    /**
     * @dev Schedules an operation to be executed.
     * @param target The address of the contract to call.
     * @param data The encoded function call.
     * @param eta The estimated time of arrival (Unix timestamp) for the operation.
     * @param predecessor The index of the predecessor operation (0 if none).
     * @return The ID of the scheduled operation.
     */
    function schedule(
        address target,
        bytes calldata data,
        uint256 eta,
        uint256 predecessor
    ) external onlyRole(SCHEDULER_ROLE) returns (uint256) {
        require(eta >= block.timestamp + minDelay, "TimelockController: eta too early");
        require(predecessor < operations.length, "TimelockController: invalid predecessor");

        if (predecessor != 0) {
            Operation storage predOp = operations[predecessor - 1];
            require(predOp.executed && !predOp.cancelled, "TimelockController: predecessor not executed or cancelled");
            require(eta >= predOp.eta, "TimelockController: eta too early for predecessor");
        }

        uint256 id = operations.length + 1;
        operations.push(Operation({
            target: target,
            data: data,
            eta: eta,
            predecessor: predecessor,
            executed: false,
            cancelled: false
        }));

        emit OperationScheduled(id, target, data, eta, predecessor);
        return id;
    }

    /**
     * @dev Executes a scheduled operation.
     * @param id The ID of the operation to execute.
     */
    function execute(uint256 id) external {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "TimelockController: caller is not the executor");
        require(id > 0 && id <= operations.length, "TimelockController: invalid operation ID");

        Operation storage op = operations[id - 1];
        require(!op.executed, "TimelockController: operation already executed");
        require(!op.cancelled, "TimelockController: operation cancelled");
        require(block.timestamp >= op.eta, "TimelockController: operation not yet due");

        if (op.predecessor != 0) {
            Operation storage predOp = operations[op.predecessor - 1];
            require(predOp.executed && !predOp.cancelled, "TimelockController: predecessor not executed or cancelled");
        }

        op.executed = true;
        lastExecutedTimestamp = block.timestamp;

        (bool success, ) = op.target.call(op.data);
        require(success, "TimelockController: operation failed");

        emit OperationExecuted(id);
    }

    /**
     * @dev Cancels a scheduled operation.
     * @param id The ID of the operation to cancel.
     */
    function cancel(uint256 id) external {
        require(hasRole(CANCELLER_ROLE, msg.sender), "TimelockController: caller is not the canceller");
        require(id > 0 && id <= operations.length, "TimelockController: invalid operation ID");

        Operation storage op = operations[id - 1];
        require(!op.executed, "TimelockController: operation already executed");
        require(!op.cancelled, "TimelockController: operation already cancelled");

        op.cancelled = true;

        emit OperationCancelled(id);
    }

    /**
     * @dev Changes the minimum delay.
     * @param newMinDelay The new minimum delay in seconds.
     */
    function setMinDelay(uint256 newMinDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minDelay = newMinDelay;
        emit MinDelayChanged(newMinDelay);
    }

    /**
     * @dev Gets the details of a scheduled operation.
     * @param id The ID of the operation.
     * @return target The address of the contract to call.
     * @return data The encoded function call.
     * @return eta The estimated time of arrival (Unix timestamp).
     * @return predecessor The index of the predecessor operation.
     * @return executed Whether the operation has been executed.
     * @return cancelled Whether the operation has been cancelled.
     */
    function getOperation(uint256 id)
        external
        view
        returns (
            address target,
            bytes memory data,
            uint256 eta,
            uint256 predecessor,
            bool executed,
            bool cancelled
        )
    {
        require(id > 0 && id <= operations.length, "TimelockController: invalid operation ID");
        Operation storage op = operations[id - 1];
        return (op.target, op.data, op.eta, op.predecessor, op.executed, op.cancelled);
    }

    /**
     * @dev Returns the total number of scheduled operations.
     */
    function getOperationCount() external view returns (uint256) {
        return operations.length;
    }

    /**
     * @dev Returns the timestamp of the last executed operation.
     */
    function getLastExecutedTimestamp() external view returns (uint256) {
        return lastExecutedTimestamp;
    }
}