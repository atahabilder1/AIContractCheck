// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    uint public required;
    uint public transactionCount;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint approvalCount;
    }

    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public approvals;

    event SubmitTransaction(address indexed owner, uint indexed transactionId);
    event ConfirmTransaction(address indexed owner, uint indexed transactionId);
    event ExecuteTransaction(uint indexed transactionId);

    modifier onlyOwner() {
        bool isOwner = false;
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "MultiSigWallet: Not an owner");
        _;
    }

    modifier transactionExists(uint _transactionId) {
        require(_transactionId < transactionCount, "MultiSigWallet: Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _transactionId) {
        require(!transactions[_transactionId].executed, "MultiSigWallet: Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "MultiSigWallet: At least one owner is required");
        require(_required > 0 && _required <= _owners.length, "MultiSigWallet: Invalid number of required confirmations");
        owners = _owners;
        required = _required;
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            approvalCount: 0
        });
        transactionCount++;
        emit SubmitTransaction(msg.sender, transactionId);
    }

    function confirmTransaction(uint _transactionId) public onlyOwner transactionExists(_transactionId) notExecuted(_transactionId) {
        if (!approvals[_transactionId][msg.sender]) {
            approvals[_transactionId][msg.sender] = true;
            transactions[_transactionId].approvalCount++;
            emit ConfirmTransaction(msg.sender, _transactionId);
        }
    }

    function executeTransaction(uint _transactionId) public onlyOwner transactionExists(_transactionId) notExecuted(_transactionId) {
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.approvalCount >= required, "MultiSigWallet: Not enough approvals");
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "MultiSigWallet: Transaction execution failed");
        emit ExecuteTransaction(_transactionId);
    }
}