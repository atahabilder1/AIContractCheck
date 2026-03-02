// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic Timelock Contract
contract Timelock {
    address public admin;
    uint256 public delay;
    uint256 public constant MINIMUM_DELAY = 1 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    mapping(bytes32 => bool) public queuedTransactions;

    event NewAdmin(address indexed newAdmin);
    event NewDelay(uint256 indexed newDelay);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(address _admin, uint256 _delay) {
        require(_delay >= MINIMUM_DELAY && _delay <= MAXIMUM_DELAY, "Invalid delay");
        admin = _admin;
        delay = _delay;
    }

    receive() external payable {}

    function setDelay(uint256 _delay) external {
        require(msg.sender == address(this), "Must be called via timelock");
        require(_delay >= MINIMUM_DELAY && _delay <= MAXIMUM_DELAY, "Invalid delay");
        delay = _delay;
        emit NewDelay(_delay);
    }

    function setAdmin(address _admin) external {
        require(msg.sender == address(this), "Must be called via timelock");
        require(_admin != address(0), "Invalid admin");
        admin = _admin;
        emit NewAdmin(_admin);
    }

    function queueTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "ETA too soon");

        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));

        require(queuedTransactions[txHash], "Not queued");
        require(block.timestamp >= eta, "Not ready");
        require(block.timestamp <= eta + 14 days, "Stale transaction");

        queuedTransactions[txHash] = false;

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");

        emit ExecuteTransaction(txHash, target, value, data, eta);
        return result;
    }

    function getTransactionHash(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, eta));
    }
}
