// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    address public owner;
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;

    mapping(bytes32 => bool) public queued;

    event Queue(bytes32 indexed txId, address indexed target, uint256 value, bytes data, uint256 executeAfter);
    event Execute(bytes32 indexed txId, address indexed target, uint256 value, bytes data);
    event Cancel(bytes32 indexed txId);

    error NotOwner();
    error AlreadyQueued(bytes32 txId);
    error NotQueued(bytes32 txId);
    error TimelockNotReady(uint256 executeAfter, uint256 currentTime);
    error TimelockExpired(uint256 executeAfter, uint256 currentTime);
    error ExecutionFailed();
    error InvalidDelay(uint256 delay);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getTxId(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _executeAfter
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_target, _value, _data, _executeAfter));
    }

    function queue(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _delay
    ) external onlyOwner returns (bytes32 txId) {
        if (_delay < MIN_DELAY || _delay > MAX_DELAY) revert InvalidDelay(_delay);

        uint256 executeAfter = block.timestamp + _delay;
        txId = getTxId(_target, _value, _data, executeAfter);

        if (queued[txId]) revert AlreadyQueued(txId);

        queued[txId] = true;
        emit Queue(txId, _target, _value, _data, executeAfter);
    }

    function execute(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _executeAfter
    ) external onlyOwner returns (bytes memory) {
        bytes32 txId = getTxId(_target, _value, _data, _executeAfter);

        if (!queued[txId]) revert NotQueued(txId);
        if (block.timestamp < _executeAfter) revert TimelockNotReady(_executeAfter, block.timestamp);
        if (block.timestamp > _executeAfter + 1 days) revert TimelockExpired(_executeAfter, block.timestamp);

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