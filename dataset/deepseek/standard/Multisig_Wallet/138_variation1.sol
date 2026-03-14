// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    uint public required;
    mapping(address => bool) public isOwner;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        mapping(address => bool) approvals;
        uint approvalsCount;
    }

    Transaction[] public transactions;

    event Deposit(address indexed sender, uint amount);
    event Submission(uint indexed transactionId);
    event Approval(uint indexed transactionId, address indexed owner);
    event Execution(uint indexed transactionId);
    event OwnerRemoval(address indexed owner);
    event OwnerAddition(address indexed owner);
    event OwnershipTransfer(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only owners can perform this action");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!transactions[_txId].approvals[msg.sender], "Transaction already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0 && _required > 0 && _required <= _owners.length, "Invalid owners or required");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0) && !isOwner[owner], "Invalid owner");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txId = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        transactions[txId].approvals[msg.sender] = true;
        transactions[txId].approvalsCount++;
        emit Submission(txId);
    }

    function approveTransaction(uint _txId) public onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
        transactions[_txId].approvals[msg.sender] = true;
        transactions[_txId].approvalsCount++;
        emit Approval(_txId, msg.sender);
    }

    function executeTransaction(uint _txId) public onlyOwner txExists(_txId) notExecuted(_txId) {
        require(transactions[_txId].approvalsCount >= required, "Not enough approvals");
        Transaction storage txn = transactions[_txId];
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");
        txn.executed = true;
        emit Execution(_txId);
    }

    function removeOwner(address _owner) public onlyOwner {
        require(owners.length > 1, "Cannot remove the last owner");
        require(isOwner[_owner], "Owner does not exist");
        isOwner[_owner] = false;
        for (uint i = 0; i < owners.length - 1; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();
        emit OwnerRemoval(_owner);
    }

    function addOwner(address _owner) public onlyOwner {
        require(_owner != address(0) && !isOwner[_owner], "Invalid owner");
        isOwner[_owner] = true;
        owners.push(_owner);
        emit OwnerAddition(_owner);
    }

    function changeOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        isOwner[msg.sender] = false;
        isOwner[_newOwner] = true;
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                owners[i] = _newOwner;
                break;
            }
        }
        emit OwnershipTransfer(msg.sender, _newOwner);
    }
}