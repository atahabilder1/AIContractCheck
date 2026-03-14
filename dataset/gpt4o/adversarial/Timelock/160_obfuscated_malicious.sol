// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public admin;
    address public emergencyAdmin;
    bool public paused;
    uint256 public constant MIN_DELAY = 1 days;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 timestamp;
        bool executed;
    }

    mapping(bytes32 => Transaction) public transactions;

    event QueueTransaction(bytes32 indexed txId, address indexed to, uint256 value, bytes data, uint256 timestamp);
    event ExecuteTransaction(bytes32 indexed txId, address indexed to, uint256 value, bytes data);
    event CancelTransaction(bytes32 indexed txId);
    event Paused();
    event Unpaused();
    event EmergencyWithdrawal(address indexed to, uint256 value);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not admin");
        _;
    }

    modifier onlyEmergencyAdmin() {
        require(msg.sender == emergencyAdmin, "Timelock: caller is not emergency admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "Timelock: paused");
        _;
    }

    constructor(address _admin, address _emergencyAdmin) {
        admin = _admin;
        emergencyAdmin = _emergencyAdmin;
    }

    function queueTransaction(address to, uint256 value, bytes calldata data, uint256 timestamp) external onlyAdmin notPaused returns (bytes32) {
        require(timestamp >= block.timestamp + MIN_DELAY, "Timelock: timestamp must be in the future");

        bytes32 txId = keccak256(abi.encode(to, value, data, timestamp));
        transactions[txId] = Transaction(to, value, data, timestamp, false);

        emit QueueTransaction(txId, to, value, data, timestamp);
        return txId;
    }

    function executeTransaction(bytes32 txId) external payable onlyAdmin notPaused {
        Transaction storage txn = transactions[txId];
        require(txn.timestamp != 0, "Timelock: transaction does not exist");
        require(!txn.executed, "Timelock: transaction already executed");
        require(block.timestamp >= txn.timestamp, "Timelock: transaction timestamp not reached");

        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Timelock: transaction execution failed");

        emit ExecuteTransaction(txId, txn.to, txn.value, txn.data);
    }

    function cancelTransaction(bytes32 txId) external onlyAdmin {
        Transaction storage txn = transactions[txId];
        require(txn.timestamp != 0, "Timelock: transaction does not exist");
        require(!txn.executed, "Timelock: transaction already executed");

        delete transactions[txId];

        emit CancelTransaction(txId);
    }

    function pause() external onlyEmergencyAdmin {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyEmergencyAdmin {
        paused = false;
        emit Unpaused();
    }

    function emergencyWithdraw(address payable to) external onlyEmergencyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "Timelock: no funds to withdraw");

        (bool success, ) = to.call{value: balance}("");
        require(success, "Timelock: emergency withdrawal failed");

        emit EmergencyWithdrawal(to, balance);
    }
}