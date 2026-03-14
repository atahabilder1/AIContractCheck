// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    address public admin;
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    bool public paused;

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 executeAfter;
        bool executed;
    }

    mapping(bytes32 => Transaction) public queuedTransactions;

    event TransactionQueued(bytes32 indexed txId, address indexed target, uint256 value, bytes data, uint256 executeAfter);
    event TransactionExecuted(bytes32 indexed txId);
    event TransactionCancelled(bytes32 indexed txId);
    event EmergencyWithdrawal(address indexed to, uint256 amount);
    event Paused(bool isPaused);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    receive() external payable {}

    function queueTransaction(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _delay
    ) external onlyAdmin whenNotPaused returns (bytes32) {
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY, "Delay out of range");

        uint256 executeAfter = block.timestamp + _delay;
        bytes32 txId = keccak256(abi.encode(_target, _value, _data, executeAfter));

        require(queuedTransactions[txId].executeAfter == 0, "Already queued");

        queuedTransactions[txId] = Transaction({
            target: _target,
            value: _value,
            data: _data,
            executeAfter: executeAfter,
            executed: false
        });

        emit TransactionQueued(txId, _target, _value, _data, executeAfter);
        return txId;
    }

    function executeTransaction(bytes32 _txId) external onlyAdmin whenNotPaused {
        Transaction storage txn = queuedTransactions[_txId];
        require(txn.executeAfter != 0, "Not queued");
        require(!txn.executed, "Already executed");
        require(block.timestamp >= txn.executeAfter, "Too early");
        require(block.timestamp <= txn.executeAfter + 14 days, "Transaction expired");

        txn.executed = true;

        (bool success, ) = txn.target.call{value: txn.value}(txn.data);
        require(success, "Execution failed");

        emit TransactionExecuted(_txId);
    }

    function cancelTransaction(bytes32 _txId) external onlyAdmin {
        require(queuedTransactions[_txId].executeAfter != 0, "Not queued");
        delete queuedTransactions[_txId];
        emit TransactionCancelled(_txId);
    }

    // --- Emergency Admin Functions ---

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");

        (bool success, ) = admin.call{value: balance}("");
        require(success, "Withdraw failed");

        emit EmergencyWithdrawal(admin, balance);
    }

    function emergencyPause() external onlyAdmin {
        paused = true;
        emit Paused(true);
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Paused(false);
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Zero address");
        emit AdminTransferred(admin, _newAdmin);
        admin = _newAdmin;
    }
}