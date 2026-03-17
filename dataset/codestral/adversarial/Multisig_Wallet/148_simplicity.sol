// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSigWallet {
    address[] public owners;
    uint required;
    mapping(address => bool) public isOwner;

    constructor(uint _required, address[] memory _owners) {
        require(_required > 0 && _required <= _owners.length, "Invalid number of required signatures");
        required = _required;
        for (uint i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
    }

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        mapping(address => bool) approvals;
    }

    Transaction[] public transactions;

    function submitTransaction(address _to, uint _value, bytes memory _data) public {
        require(isOwner[msg.sender], "Only owners can submit transactions");
        transactions.push(Transaction({to: _to, value: _value, data: _data}));
    }

    function approveTransaction(uint _txId) public {
        require(isOwner[msg.sender], "Only owners can approve transactions");
        Transaction storage tx = transactions[_txId];
        require(!tx.approvals[msg.sender] && !tx.executed, "You have already approved or the transaction has been executed");
        tx.approvals[msg.sender] = true;
        if (getApprovalsCount(tx) >= required) {
            executeTransaction(_txId);
        }
    }

    function getApprovalsCount(Transaction memory _tx) private view returns (uint) {
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (_tx.approvals[owners[i]]) {
                count++;
            }
        }
        return count;
    }

    function executeTransaction(uint _txId) internal {
        Transaction storage tx = transactions[_txId];
        require(!tx.executed, "The transaction has already been executed");
        tx.to.call{value: tx.value}(tx.data);
        tx.executed = true;
    }
}