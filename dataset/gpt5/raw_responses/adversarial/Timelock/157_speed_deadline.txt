// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    // Ownership (two-step)
    address public owner;
    address public pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Timelock config
    uint256 public minDelay;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    event MinDelayUpdated(uint256 oldDelay, uint256 newDelay);

    // Operation storage
    struct Operation {
        address target;
        uint256 value;
        bytes data;
        uint256 executeAfter;
        bool queued;
    }

    mapping(bytes32 => Operation) private ops;
    uint256 public queueNonce;

    event Queued(bytes32 indexed id, address indexed target, uint256 value, bytes data, uint256 executeAfter);
    event Cancelled(bytes32 indexed id);
    event Executed(bytes32 indexed id, address indexed target, uint256 value, bytes data, bytes result);

    constructor(address _owner, uint256 _minDelay) {
        require(_owner != address(0), "Owner=0");
        require(_minDelay <= MAX_DELAY, "Delay too big");
        owner = _owner;
        minDelay = _minDelay;
        emit OwnershipTransferred(address(0), _owner);
    }

    // Funding
    receive() external payable {}
    fallback() external payable {}

    // Owner management
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner=0");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        address old = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(old, owner);
    }

    // Delay management (only allow non-decreasing to avoid bypass)
    function setMinDelay(uint256 newDelay) external onlyOwner {
        require(newDelay >= minDelay, "Cannot decrease delay");
        require(newDelay <= MAX_DELAY, "Delay too big");
        uint256 old = minDelay;
        minDelay = newDelay;
        emit MinDelayUpdated(old, newDelay);
    }

    // Queue an operation; returns operation id
    function queue(address target, uint256 value, bytes calldata data, uint256 delay) external onlyOwner returns (bytes32 id) {
        require(target != address(0), "Target=0");
        require(delay >= minDelay, "Delay too short");
        require(delay <= MAX_DELAY, "Delay too big");

        uint256 executeAfter = block.timestamp + delay;
        uint256 nonce = ++queueNonce;
        id = keccak256(abi.encodePacked(address(this), nonce, target, value, data, executeAfter));
        require(!ops[id].queued, "Already queued");

        ops[id] = Operation({
            target: target,
            value: value,
            data: data,
            executeAfter: executeAfter,
            queued: true
        });

        emit Queued(id, target, value, data, executeAfter);
    }

    // Cancel a queued operation
    function cancel(bytes32 id) external onlyOwner {
        Operation storage op = ops[id];
        require(op.queued, "Not queued");
        delete ops[id];
        emit Cancelled(id);
    }

    // Execute an operation after the delay and before grace period ends
    function execute(bytes32 id) external returns (bytes memory result) {
        Operation storage op = ops[id];
        require(op.queued, "Not queued");
        require(block.timestamp >= op.executeAfter, "Too early");
        require(block.timestamp <= op.executeAfter + GRACE_PERIOD, "Grace period passed");
        require(address(this).balance >= op.value, "Insufficient balance");

        address target = op.target;
        uint256 value = op.value;
        bytes memory data = op.data;

        // Effects before interaction
        delete ops[id];

        (bool ok, bytes memory res) = target.call{value: value}(data);
        require(ok, "Underlying call failed");

        emit Executed(id, target, value, data, res);
        return res;
    }

    // Views
    function getOperation(bytes32 id) external view returns (
        address target,
        uint256 value,
        bytes memory data,
        uint256 executeAfter,
        bool queued
    ) {
        Operation storage op = ops[id];
        return (op.target, op.value, op.data, op.executeAfter, op.queued);
    }

    function isQueued(bytes32 id) external view returns (bool) {
        return ops[id].queued;
    }

    function timeLeft(bytes32 id) external view returns (uint256) {
        Operation storage op = ops[id];
        if (!op.queued) return 0;
        if (block.timestamp >= op.executeAfter) return 0;
        return op.executeAfter - block.timestamp;
    }
}