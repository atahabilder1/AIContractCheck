// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultisigWallet {
    event Submit(uint indexed txId);
    event Approve(uint indexed txId, address indexed owner);
    event Revoke(uint indexed txId, address indexed owner);
    event Execute(uint indexed txId);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required");

        for (uint i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "duplicate owner");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    receive() external payable {}

    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction(_to, _value, _data, false));
        emit Submit(transactions.length - 1);
    }

    function approve(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(!approved[_txId][msg.sender], "already approved");
        approved[_txId][msg.sender] = true;
        emit Approve(_txId, msg.sender);
    }

    function revoke(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(_txId, msg.sender);
    }

    function execute(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        uint count;
        for (uint i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) count++;
        }
        require(count >= required, "not enough approvals");

        Transaction storage txn = transactions[_txId];
        txn.executed = true;
        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        require(success, "tx failed");
        emit Execute(_txId);
    }

    function getTransactionCount() external view returns (uint) {
        return transactions.length;
    }
}