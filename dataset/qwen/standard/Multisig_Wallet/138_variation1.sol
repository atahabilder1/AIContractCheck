// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(address indexed owner, uint indexed txIndex, uint value, address payable to, bytes data);
    event ApproveTransaction(address indexed owner, uint indexed txIndex);
    event RevokeApproval(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    struct Transaction {
        uint value;
        address payable to;
        bytes data;
        bool executed;
        uint approvals;
        mapping(address => bool) isApproved;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;

    mapping(uint => Transaction) public transactions;
    uint public transactionCount;

    mapping(uint => uint) public approvalThresholds;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notApproved(uint _txIndex) {
        require(!transactions[_txIndex].isApproved[msg.sender], "Transaction already approved by this owner");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(uint _value, address payable _to, bytes memory _data) public onlyOwner {
        uint txIndex = transactionCount;
        transactions[txIndex] = Transaction({
            value: _value,
            to: _to,
            data: _data,
            executed: false,
            approvals: 0
        });

        transactionCount++;

        emit SubmitTransaction(msg.sender, txIndex, _value, _to, _data);
    }

    function approveTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notApproved(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.isApproved[msg.sender] = true;
        transaction.approvals++;

        emit ApproveTransaction(msg.sender, _txIndex);
    }

    function revokeApproval(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.isApproved[msg.sender], "Transaction not approved by this owner");

        transaction.isApproved[msg.sender] = false;
        transaction.approvals--;

        emit RevokeApproval(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.approvals >= getApprovalThreshold(_txIndex), "Not enough approvals");

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function setApprovalThreshold(uint _txType, uint _threshold) public onlyOwner {
        require(_threshold > 0 && _threshold <= owners.length, "Invalid threshold");
        approvalThresholds[_txType] = _threshold;
    }

    function getApprovalThreshold(uint _txType) public view returns (uint) {
        return approvalThresholds[_txType] > 0 ? approvalThresholds[_txType] : numConfirmationsRequired;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactionCount;
    }

    function getTransaction(uint _txIndex) public view returns (uint value, address payable to, bytes memory data, bool executed, uint approvals) {
        Transaction storage transaction = transactions[_txIndex];
        return (transaction.value, transaction.to, transaction.data, transaction.executed, transaction.approvals);
    }
}