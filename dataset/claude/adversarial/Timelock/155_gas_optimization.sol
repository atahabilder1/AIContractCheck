// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Timelock {
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    address public owner;
    mapping(bytes32 => bool) public queued;

    error NotOwner();
    error AlreadyQueued(bytes32 txId);
    error NotQueued(bytes32 txId);
    error TimestampNotInRange(uint256 blockTimestamp, uint256 timestamp);
    error TimestampNotPassed(uint256 blockTimestamp, uint256 timestamp);
    error TimestampExpired(uint256 blockTimestamp, uint256 expiresAt);
    error TxFailed();

    event Queue(bytes32 indexed txId, address indexed target, uint256 value, string func, bytes data, uint256 timestamp);
    event Execute(bytes32 indexed txId, address indexed target, uint256 value, string func, bytes data, uint256 timestamp);
    event Cancel(bytes32 indexed txId);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function getTxId(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_target, _value, _func, _data, _timestamp));
    }

    function queue(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external onlyOwner returns (bytes32 txId) {
        txId = getTxId(_target, _value, _func, _data, _timestamp);

        if (queued[txId]) revert AlreadyQueued(txId);
        if (_timestamp < block.timestamp + MIN_DELAY || _timestamp > block.timestamp + MAX_DELAY)
            revert TimestampNotInRange(block.timestamp, _timestamp);

        queued[txId] = true;
        emit Queue(txId, _target, _value, _func, _data, _timestamp);
    }

    function execute(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external payable onlyOwner returns (bytes memory) {
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);

        if (!queued[txId]) revert NotQueued(txId);
        if (block.timestamp < _timestamp) revert TimestampNotPassed(block.timestamp, _timestamp);
        if (block.timestamp > _timestamp + GRACE_PERIOD) revert TimestampExpired(block.timestamp, _timestamp + GRACE_PERIOD);

        delete queued[txId];

        bytes memory data;
        if (bytes(_func).length > 0) {
            data = abi.encodePacked(bytes4(keccak256(bytes(_func))), _data);
        } else {
            data = _data;
        }

        (bool ok, bytes memory res) = _target.call{value: _value}(data);
        if (!ok) revert TxFailed();

        emit Execute(txId, _target, _value, _func, _data, _timestamp);
        return res;
    }

    function cancel(bytes32 _txId) external onlyOwner {
        if (!queued[_txId]) revert NotQueued(_txId);
        delete queued[_txId];
        emit Cancel(_txId);
    }
}