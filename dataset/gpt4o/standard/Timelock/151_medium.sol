// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    event NewAdmin(address indexed newAdmin);
    event NewDelay(uint256 indexed newDelay);
    event NewGracePeriod(uint256 indexed newGracePeriod);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);

    address public admin;
    uint256 public delay;
    uint256 public gracePeriod;

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(address admin_, uint256 delay_, uint256 gracePeriod_) {
        require(delay_ > 0, "Timelock: Delay must be greater than zero.");
        require(gracePeriod_ > 0, "Timelock: Grace period must be greater than zero.");
        admin = admin_;
        delay = delay_;
        gracePeriod = gracePeriod_;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: Caller is not the admin.");
        _;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Timelock: New admin cannot be the zero address.");
        admin = newAdmin;
        emit NewAdmin(newAdmin);
    }

    function setDelay(uint256 newDelay) external onlyAdmin {
        require(newDelay > 0, "Timelock: Delay must be greater than zero.");
        delay = newDelay;
        emit NewDelay(newDelay);
    }

    function setGracePeriod(uint256 newGracePeriod) external onlyAdmin {
        require(newGracePeriod > 0, "Timelock: Grace period must be greater than zero.");
        gracePeriod = newGracePeriod;
        emit NewGracePeriod(newGracePeriod);
    }

    function queueTransaction(address target, uint256 value, bytes calldata data, uint256 eta) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Timelock: ETA must satisfy delay.");
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint256 value, bytes calldata data, uint256 eta) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, data, eta);
    }

    function executeTransaction(address target, uint256 value, bytes calldata data, uint256 eta) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        require(queuedTransactions[txHash], "Timelock: Transaction hasn't been queued.");
        require(block.timestamp >= eta, "Timelock: Transaction hasn't surpassed time lock.");
        require(block.timestamp <= eta + gracePeriod, "Timelock: Transaction is stale.");

        queuedTransactions[txHash] = false;

        (bool success, bytes memory returnData) = target.call{value: value}(data);
        require(success, "Timelock: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, data, eta);

        return returnData;
    }

    function batchExecuteTransactions(address[] calldata targets, uint256[] calldata values, bytes[] calldata data, uint256[] calldata etas) external payable onlyAdmin {
        require(targets.length == values.length && targets.length == data.length && targets.length == etas.length, "Timelock: Input array lengths mismatch.");
        for (uint256 i = 0; i < targets.length; i++) {
            executeTransaction(targets[i], values[i], data[i], etas[i]);
        }
    }

    receive() external payable {}
}