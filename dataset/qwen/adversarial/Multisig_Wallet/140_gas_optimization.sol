// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint public required;

    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public confirmations;

    struct Transaction {
        address payable destination;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(uint indexed txIndex, address indexed owner, address indexed destination, uint value, bytes data);
    event ConfirmTransaction(uint indexed txIndex, address indexed owner);
    event ExecuteTransaction(uint indexed txIndex);
    event RevokeConfirmation(uint indexed txIndex, address indexed owner);

    modifier onlyOwner() {
        require(isOwner(msg.sender), "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(transactions[_txIndex].destination != address(0), "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    modifier confirmed(uint _txIndex) {
        require(confirmations[_txIndex][msg.sender], "tx not confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");
        for (uint i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "invalid owner");
            owners.push(_owners[i]);
        }
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address payable _destination, uint _value, bytes memory _data) external onlyOwner {
        uint txIndex = transactions.length;
        transactions[txIndex] = Transaction(_destination, _value, _data, false, 0);
        emit SubmitTransaction(txIndex, msg.sender, _destination, _value, _data);
        confirmTransaction(txIndex);
    }

    function confirmTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notConfirmed(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        confirmations[_txIndex][msg.sender] = true;
        transaction.numConfirmations += 1;
        emit ConfirmTransaction(_txIndex, msg.sender);
        if (transaction.numConfirmations >= required) {
            executeTransaction(_txIndex);
        }
    }

    function executeTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.numConfirmations >= required, "not enough confirmations");
        transaction.executed = true;
        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");
        emit ExecuteTransaction(_txIndex);
    }

    function revokeConfirmation(uint _txIndex) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) confirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        confirmations[_txIndex][msg.sender] = false;
        transaction.numConfirmations -= 1;
        emit RevokeConfirmation(_txIndex, msg.sender);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function isOwner(address _account) public view returns (bool) {
        for (uint i; i < owners.length; i++) {
            if (owners[i] == _account) {
                return true;
            }
        }
        return false;
    }
}