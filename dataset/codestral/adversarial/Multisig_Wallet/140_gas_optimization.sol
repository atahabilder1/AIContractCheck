// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    uint numConfirmationsRequired;
    address[] public owners;
    mapping(address => bool) isOwner;
    mapping(uint256 => bool) executedTransactions;

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "At least one owner required");
        require(_numConfirmationsRequired <= _owners.length, "Num confirmations must be less than or equal to the number of owners");

        numConfirmationsRequired = _numConfirmationsRequired;
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid zero address");
            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        mapping(address => bool) confirmations;
    }

    mapping(uint256 => Transaction) transactions;
    uint256 transactionCount = 0;

    function submitTransaction(address _to, uint _value, bytes memory _data) public {
        require(isOwner[msg.sender], "Only owners can submit transactions");

        transactions[transactionCount] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        });

        transactionCount++;
    }

    function confirmTransaction(uint256 _transactionId) public {
        require(isOwner[msg.sender], "Only owners can confirm transactions");
        Transaction memory tx = transactions[_transactionId];
        require(!tx.executed, "Transaction already executed");
        require(!tx.confirmations[msg.sender], "Already confirmed");

        tx.confirmations[msg.sender] = true;
        transactions[_transactionId] = tx;
    }

    function executeTransaction(uint256 _transactionId) public {
        Transaction memory tx = transactions[_transactionId];
        require(!tx.executed, "Transaction already executed");
        require(!executedTransactions[_transactionId], "Duplicate execution attempt");

        uint confirmationsCount = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (tx.confirmations[owners[i]]) {
                confirmationsCount++;
            }
        }

        require(confirmationsCount >= numConfirmationsRequired, "Not enough confirmations");

        tx.to.call{value: tx.value}(tx.data);
        tx.executed = true;
        executedTransactions[_transactionId] = true;
        transactions[_transactionId] = tx;
    }
}