// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[3] public owners;
    mapping(address => bool) public isOwner;
    uint constant public requiredApprovals = 2;

    struct Transaction {
        address destination;
        uint value;
        bool executed;
        uint8 approvalCount;
    }

    mapping(uint => mapping(address => bool)) public approvals;
    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notApproved(uint _txIndex) {
        require(!approvals[_txIndex][msg.sender], "Transaction already approved");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    constructor(address[3] memory _owners) {
        for (uint i = 0; i < 3; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");

            owners[i] = _owners[i];
            isOwner[_owners[i]] = true;
        }
    }

    receive() external payable {}

    function submitTransaction(address _destination, uint _value) external onlyOwner {
        transactions.push(Transaction({
            destination: _destination,
            value: _value,
            executed: false,
            approvalCount: 0
        }));
    }

    function approveTransaction(uint _txIndex) 
        external 
        onlyOwner 
        txExists(_txIndex) 
        notApproved(_txIndex) 
        notExecuted(_txIndex) 
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.approvalCount += 1;
        approvals[_txIndex][msg.sender] = true;
    }

    function executeTransaction(uint _txIndex) 
        external 
        onlyOwner 
        txExists(_txIndex) 
        notExecuted(_txIndex) 
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.approvalCount >= requiredApprovals, "Insufficient approvals");

        transaction.executed = true;
        (bool success, ) = transaction.destination.call{value: transaction.value}("");
        require(success, "Transaction failed");
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        public
        view
        returns (address destination, uint value, bool executed, uint8 approvalCount)
    {
        Transaction memory transaction = transactions[_txIndex];
        return (
            transaction.destination,
            transaction.value,
            transaction.executed,
            transaction.approvalCount
        );
    }
}