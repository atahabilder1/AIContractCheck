// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    address public admin;
    uint256 public immutable delay;
    uint256 public constant GRACE_PERIOD = 14 days;

    mapping(bytes32 => bool) public queuedTransactions;

    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta, bytes result);

    error NotAdmin();
    error InvalidTarget();
    error TimestampTooSoon(uint256 eta, uint256 required);
    error AlreadyQueued(bytes32 txHash);
    error NotQueued(bytes32 txHash);
    error TimestampNotReady(uint256 nowTs, uint256 eta);
    error TransactionStale(uint256 nowTs, uint256 expiry);
    error CallFailed();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(address admin_, uint256 delay_) {
        require(admin_ != address(0), "admin zero");
        require(delay_ > 0, "delay zero");
        admin = admin_;
        delay = delay_;
    }

    receive() external payable {}

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "admin zero");
        admin = newAdmin;
    }

    function getTxHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        if (target == address(0)) revert InvalidTarget();
        uint256 requiredEta = block.timestamp + delay;
        if (eta < requiredEta) revert TimestampTooSoon(eta, requiredEta);

        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        if (queuedTransactions[txHash]) revert AlreadyQueued(txHash);

        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        if (!queuedTransactions[txHash]) revert NotQueued(txHash);

        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        if (!queuedTransactions[txHash]) revert NotQueued(txHash);
        if (block.timestamp < eta) revert TimestampNotReady(block.timestamp, eta);
        uint256 expiry = eta + GRACE_PERIOD;
        if (block.timestamp > expiry) revert TransactionStale(block.timestamp, expiry);

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory result) = target.call{value: value}(callData);
        if (!success) revert CallFailed();

        emit ExecuteTransaction(txHash, target, value, signature, data, eta, result);
        return result;
    }
}