// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;

    address public owner;
    mapping(bytes32 => bool) public queued;

    event Queue(bytes32 indexed txId, address indexed target, uint256 value, bytes data, uint256 executeAfter);
    event Execute(bytes32 indexed txId, address indexed target, uint256 value, bytes data);
    event Cancel(bytes32 indexed txId);

    error NotOwner();
    error AlreadyQueued(bytes32 txId);
    error NotQueued(bytes32 txId);
    error TimelockNotReady(uint256 executeAfter);
    error TimelockExpired(uint256 executeAfter);
    error InvalidDelay(uint256 delay);
    error ExecutionFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function queue(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _delay
    ) external onlyOwner returns (bytes32) {
        if (_delay < MIN_DELAY || _delay > MAX_DELAY) revert InvalidDelay(_delay);

        uint256 executeAfter = block.timestamp + _delay;
        bytes32 txId = keccak256(abi.encode(_target, _value, _data, executeAfter));

        if (queued[txId]) revert AlreadyQueued(txId);

        queued[txId] = true;
        emit Queue(txId, _target, _value, _data, executeAfter);
        return txId;
    }

    function execute(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _executeAfter
    ) external payable onlyOwner returns (bytes memory) {
        bytes32 txId = keccak256(abi.encode(_target, _value, _data, _executeAfter));

        if (!queued[txId]) revert NotQueued(txId);
        if (block.timestamp < _executeAfter) revert TimelockNotReady(_executeAfter);
        if (block.timestamp > _executeAfter + MAX_DELAY) revert TimelockExpired(_executeAfter);

        queued[txId] = false;

        (bool ok, bytes memory result) = _target.call{value: _value}(_data);
        if (!ok) revert ExecutionFailed();

        emit Execute(txId, _target, _value, _data);
        return result;
    }

    function cancel(bytes32 _txId) external onlyOwner {
        if (!queued[_txId]) revert NotQueued(_txId);
        queued[_txId] = false;
        emit Cancel(_txId);
    }

    receive() external payable {}
}