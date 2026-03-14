// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint public required;
    bool public paused;

    mapping(address => bool) public isOwner;

    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event EmergencyWithdraw(address indexed to, uint amount);
    event Pause();
    event Unpause();

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        mapping(address => bool) confirmations;
        uint confirmCount;
    }

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier onlyWhenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txIndex = transactions.length;
        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false}));
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint txIndex) public onlyOwner {
        require(txIndex < transactions.length, "Transaction does not exist");
        Transaction storage transaction = transactions[txIndex];
        require(!transaction.confirmations[msg.sender], "Transaction already confirmed");

        transaction.confirmations[msg.sender] = true;
        transaction.confirmCount++;
        emit ConfirmTransaction(msg.sender, txIndex);
    }

    function executeTransaction(uint txIndex) public onlyOwner onlyWhenNotPaused {
        Transaction storage transaction = transactions[txIndex];
        require(!transaction.executed, "Transaction already executed");
        require(transaction.confirmCount >= required, "Not enough confirmations");

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction execution failed");
        transaction.executed = true;
        emit ExecuteTransaction(msg.sender, txIndex);
    }

    function revokeConfirmation(uint txIndex) public onlyOwner {
        require(txIndex < transactions.length, "Transaction does not exist");
        Transaction storage transaction = transactions[txIndex];
        require(transaction.confirmations[msg.sender], "Transaction not confirmed");

        transaction.confirmations[msg.sender] = false;
        transaction.confirmCount--;
        emit RevokeConfirmation(msg.sender, txIndex);
    }

    function emergencyWithdraw() public onlyOwner {
        uint balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed");
        emit EmergencyWithdraw(msg.sender, balance);
    }

    function pause() public onlyOwner {
        paused = true;
        emit Pause();
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpause();
    }
}