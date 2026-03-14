// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint256 public requiredConfirmations;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    uint256 public transactionCount;

    struct Transaction {
        address payable destination;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    event Deposit(address indexed sender, uint256 value);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);

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

    modifier transactionExists(uint256 _txId) {
        require(_txId < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txId) {
        require(!confirmations[_txId][msg.sender], "Transaction already confirmed by sender");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners must be at least one");
        require(_requiredConfirmations > 0, "Required confirmations must be at least one");
        require(_requiredConfirmations <= _owners.length, "Required confirmations cannot exceed number of owners");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Owner cannot be zero address");
            owners.push(_owners[i]);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address payable _destination, uint256 _value, bytes memory _data) public onlyOwner returns (uint256 transactionId) {
        transactionCount++;
        transactions[transactionCount] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        });
        emit Submission(transactionCount);
        return transactionCount;
    }

    function confirmTransaction(uint256 _txId) public onlyOwner transactionExists(_txId) notExecuted(_txId) notConfirmed(_txId) {
        require(transactions[_txId].confirmationCount < owners.length, "Transaction already has enough confirmations");
        confirmations[_txId][msg.sender] = true;
        transactions[_txId].confirmationCount++;
        emit Confirmation(msg.sender, _txId);

        if (transactions[_txId].confirmationCount >= requiredConfirmations) {
            executeTransaction(_txId);
        }
    }

    function revokeConfirmation(uint256 _txId) public onlyOwner transactionExists(_txId) notExecuted(_txId) {
        require(confirmations[_txId][msg.sender], "Sender has not confirmed this transaction");
        confirmations[_txId][msg.sender] = false;
        transactions[_txId].confirmationCount--;
        emit Revocation(msg.sender, _txId);
    }

    function executeTransaction(uint256 _txId) public transactionExists(_txId) notExecuted(_txId) {
        require(transactions[_txId].confirmationCount >= requiredConfirmations, "Not enough confirmations to execute");

        transactions[_txId].executed = true;

        (bool success, ) = transactions[_txId].destination.call{value: transactions[_txId].value}(transactions[_txId].data);

        if (success) {
            emit Execution(_txId);
        } else {
            emit ExecutionFailure(_txId);
            // Revert execution state if call fails, but keep it marked as 'executed' to prevent re-attempts
            // or handle this more robustly depending on desired behavior.
            // For hackathon speed, we'll leave it marked as executed.
        }
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 _txId) public view returns (address destination, uint256 value, bytes memory data, bool executed, uint256 confirmationCount) {
        Transaction storage tx = transactions[_txId];
        return (tx.destination, tx.value, tx.data, tx.executed, tx.confirmationCount);
    }

    function isConfirmed(uint256 _txId, address _owner) public view returns (bool) {
        return confirmations[_txId][_owner];
    }
}