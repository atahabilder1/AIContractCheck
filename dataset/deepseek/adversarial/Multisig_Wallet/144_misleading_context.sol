// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint public required;
    uint public transactionCount;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public confirmations;

    event Deposit(address indexed sender, uint value);
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed owner, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    modifier onlyOwner() {
        bool isOwner = false;
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "Only owner can call this function.");
        _;
    }

    modifier transactionExists(uint _txId) {
        require(_txId < transactionCount, "Transaction does not exist.");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Transaction already executed.");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0 && _required > 0 && _required <= _owners.length, "Invalid owners or required number of confirmations.");
        owners = _owners;
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txId = transactionCount;
        transactions[txId] = Transaction({to: _to, value: _value, data: _data, executed: false});
        transactionCount++;
        emit Submission(txId);
    }

    function confirmTransaction(uint _txId) public onlyOwner transactionExists(_txId) notExecuted(_txId) {
        if (!confirmations[_txId][msg.sender]) {
            confirmations[_txId][msg.sender] = true;
            emit Confirmation(msg.sender, _txId);
        }
    }

    function executeTransaction(uint _txId) public onlyOwner transactionExists(_txId) notExecuted(_txId) {
        require(getConfirmationCount(_txId) >= required, "Not enough confirmations.");
        Transaction storage txn = transactions[_txId];
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (success) {
            txn.executed = true;
            emit Execution(_txId);
        } else {
            emit ExecutionFailure(_txId);
        }
    }

    function getConfirmationCount(uint _txId) public view returns (uint count) {
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[_txId][owners[i]]) {
                count++;
            }
        }
    }

    function revokeConfirmation(uint _txId) public onlyOwner transactionExists(_txId) notExecuted(_txId) {
        require(confirmations[_txId][msg.sender], "Transaction not confirmed by this owner.");
        confirmations[_txId][msg.sender] = false;
    }
}