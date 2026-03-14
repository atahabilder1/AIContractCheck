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
        uint confirmations;
    }

    mapping(uint => mapping(address => bool)) public confirmations;
    mapping(uint => Transaction) public transactions;

    event Deposit(address indexed sender, uint amount);
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
        require(isOwner, "Only owners can call this function");
        _;
    }

    modifier transactionExists(uint _transactionId) {
        require(_transactionId < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _transactionId) {
        require(!transactions[_transactionId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0 && _required > 0 && _required <= _owners.length, "Invalid number of owners or required confirmations");
        owners = _owners;
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        });
        transactionCount++;
        emit Submission(transactionId);
    }

    function confirmTransaction(uint _transactionId) public onlyOwner transactionExists(_transactionId) notExecuted(_transactionId) {
        if (!confirmations[_transactionId][msg.sender]) {
            confirmations[_transactionId][msg.sender] = true;
            transactions[_transactionId].confirmations++;
            emit Confirmation(msg.sender, _transactionId);
        }
    }

    function executeTransaction(uint _transactionId) public onlyOwner transactionExists(_transactionId) notExecuted(_transactionId) {
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.confirmations >= required, "Not enough confirmations");
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        if (success) {
            transaction.executed = true;
            emit Execution(_transactionId);
        } else {
            emit ExecutionFailure(_transactionId);
        }
    }

    function getConfirmationCount(uint _transactionId) public view returns (uint) {
        require(_transactionId < transactionCount, "Transaction does not exist");
        return transactions[_transactionId].confirmations;
    }

    function getTransactionCount() public view returns (uint) {
        return transactionCount;
    }
}