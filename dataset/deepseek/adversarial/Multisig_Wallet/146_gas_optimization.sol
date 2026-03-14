// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    uint256 public required;
    uint256 transactionCount;
    uint256 nonce;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 nonce;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed owner, uint256 indexed transactionId);
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
        require(isOwner, "MultiSigWallet: Not an owner");
        _;
    }

    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId < transactionCount, "MultiSigWallet: Transaction does not exist");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0 && _required > 0 && _required <= _owners.length, "MultiSigWallet: Invalid number of owners or required confirmations");
        owners = _owners;
        required = _required;
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlyOwner {
        uint256 transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            nonce: nonce
        });
        transactionCount++;
        emit Submission(transactionId);
        nonce++;
    }

    function confirmTransaction(uint256 _transactionId) public onlyOwner transactionExists(_transactionId) {
        require(!transactions[_transactionId].executed, "MultiSigWallet: Transaction already executed");
        if (!confirmations[_transactionId][msg.sender]) {
            confirmations[_transactionId][msg.sender] = true;
            emit Confirmation(msg.sender, _transactionId);
        }
    }

    function executeTransaction(uint256 _transactionId) public onlyOwner transactionExists(_transactionId) {
        require(!transactions[_transactionId].executed, "MultiSigWallet: Transaction already executed");
        require(getConfirmationCount(_transactionId) >= required, "MultiSigWallet: Not enough confirmations");
        Transaction storage transaction = transactions[_transactionId];
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        if (success) {
            transaction.executed = true;
            emit Execution(_transactionId);
        } else {
            emit ExecutionFailure(_transactionId);
        }
    }

    function getConfirmationCount(uint256 _transactionId) public view returns (uint256 count) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_transactionId][owners[i]]) {
                count++;
            }
        }
    }
}