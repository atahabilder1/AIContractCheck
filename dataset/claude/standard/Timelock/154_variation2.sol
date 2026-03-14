// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProportionalTimelock {
    address public owner;
    uint256 public baseDelay = 1 days;
    uint256 public delayPerEth = 1 days;
    uint256 public maxDelay = 30 days;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 executeAfter;
        bool executed;
    }

    mapping(uint256 => Transaction) public transactions;
    uint256 public txCount;

    event TransactionQueued(uint256 indexed txId, address to, uint256 value, uint256 executeAfter);
    event TransactionExecuted(uint256 indexed txId);
    event TransactionCancelled(uint256 indexed txId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function calculateDelay(uint256 value) public view returns (uint256) {
        uint256 delay = baseDelay + (value * delayPerEth) / 1 ether;
        if (delay > maxDelay) {
            delay = maxDelay;
        }
        return delay;
    }

    function queueTransaction(address _to, uint256 _value, bytes calldata _data) external onlyOwner returns (uint256) {
        uint256 delay = calculateDelay(_value);
        uint256 executeAfter = block.timestamp + delay;

        uint256 txId = txCount++;
        transactions[txId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executeAfter: executeAfter,
            executed: false
        });

        emit TransactionQueued(txId, _to, _value, executeAfter);
        return txId;
    }

    function executeTransaction(uint256 _txId) external onlyOwner {
        Transaction storage txn = transactions[_txId];
        require(!txn.executed, "Already executed");
        require(block.timestamp >= txn.executeAfter, "Timelock not expired");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(_txId);
    }

    function cancelTransaction(uint256 _txId) external onlyOwner {
        Transaction storage txn = transactions[_txId];
        require(!txn.executed, "Already executed");

        delete transactions[_txId];

        emit TransactionCancelled(_txId);
    }

    function setBaseDelay(uint256 _baseDelay) external onlyOwner {
        baseDelay = _baseDelay;
    }

    function setDelayPerEth(uint256 _delayPerEth) external onlyOwner {
        delayPerEth = _delayPerEth;
    }

    function setMaxDelay(uint256 _maxDelay) external onlyOwner {
        maxDelay = _maxDelay;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Zero address");
        owner = _newOwner;
    }
}