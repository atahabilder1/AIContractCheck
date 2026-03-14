// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint256 public requiredConfirmations;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) confirmations;
        uint256 confirmationCount;
    }

    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;

    event Deposit(address indexed sender, uint256 value);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);

    modifier onlyOwner() {
        bool isOwner = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "Not an owner");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners cannot be empty");
        require(_requiredConfirmations > 0, "Required confirmations must be greater than 0");
        require(_requiredConfirmations <= _owners.length, "Required confirmations cannot exceed the number of owners");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Owner address cannot be zero");
            owners.push(_owners[i]);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _destination, uint256 _value, bytes memory _data) public onlyOwner returns (uint256 transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        });
        transactionCount++;
        emit Submission(transactionId);
        return transactionId;
    }

    function confirmTransaction(uint256 _transactionId) public onlyOwner {
        require(_transactionId < transactionCount, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(!transaction.executed, "Transaction already executed");
        require(!transaction.confirmations[msg.sender], "Already confirmed");

        transaction.confirmations[msg.sender] = true;
        transaction.confirmationCount++;

        emit Confirmation(msg.sender, _transactionId);
    }

    function revokeConfirmation(uint256 _transactionId) public onlyOwner {
        require(_transactionId < transactionCount, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(!transaction.executed, "Transaction already executed");
        require(transaction.confirmations[msg.sender], "Not confirmed");

        transaction.confirmations[msg.sender] = false;
        transaction.confirmationCount--;

        emit Revocation(msg.sender, _transactionId);
    }

    function executeTransaction(uint256 _transactionId) public onlyOwner {
        require(_transactionId < transactionCount, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(!transaction.executed, "Transaction already executed");
        require(transaction.confirmationCount >= requiredConfirmations, "Not enough confirmations");

        transaction.executed = true;

        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit Execution(_transactionId);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 _transactionId) public view returns (address destination, uint256 value, bytes memory data, bool executed, uint256 confirmationCount) {
        require(_transactionId < transactionCount, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        return (
            transaction.destination,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmationCount
        );
    }
}