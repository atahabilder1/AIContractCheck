// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event Submission(address indexed owner, uint256 indexed transactionId);
    event Confirmation(address indexed owner, uint256 indexed transactionId);
    event Revocation(address indexed owner, uint256 indexed transactionId);
    event Execution(address indexed owner, uint256 indexed transactionId);
    event ExecutionFailure(address indexed owner, uint256 indexed transactionId);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) confirmations;
        uint256 confirmationCount;
    }

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txId) {
        require(!transactions[_txId].confirmations[msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners array cannot be empty");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid number of required confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Owner address cannot be zero");
            require(!isOwner[owner], "Duplicate owner");
            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _destination, uint256 _value, bytes memory _data)
        public
        onlyOwner
        returns (uint256 transactionId)
    {
        transactionId = transactions.length;
        transactions.push(Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        }));
        emit Submission(msg.sender, transactionId);
        return transactionId;
    }

    function confirmTransaction(uint256 _txId) public onlyOwner txExists(_txId) notExecuted(_txId) notConfirmed(_txId) {
        transactions[_txId].confirmations[msg.sender] = true;
        transactions[_txId].confirmationCount++;
        emit Confirmation(msg.sender, _txId);
    }

    function revokeConfirmation(uint256 _txId) public onlyOwner txExists(_txId) notExecuted(_txId) {
        require(transactions[_txId].confirmations[msg.sender], "Transaction not confirmed by sender");
        transactions[_txId].confirmations[msg.sender] = false;
        transactions[_txId].confirmationCount--;
        emit Revocation(msg.sender, _txId);
    }

    function executeTransaction(uint256 _txId) public onlyOwner txExists(_txId) notExecuted(_txId) {
        require(transactions[_txId].confirmationCount >= requiredConfirmations, "Not enough confirmations");

        transactions[_txId].executed = true;

        (bool success, ) = transactions[_txId].destination.call{value: transactions[_txId].value}(transactions[_txId].data);

        if (success) {
            emit Execution(msg.sender, _txId);
        } else {
            emit ExecutionFailure(msg.sender, _txId);
            // Revert to allow retries if execution fails but confirmations are met
            // This is a design choice; alternatively, one could mark as failed and prevent retries.
            // For now, we'll just emit the failure event.
        }
    }

    function withdraw(uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        emit Withdrawal(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Withdrawal failed");
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 _txId)
        public
        view
        txExists(_txId)
        returns (
            address destination,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmationCount
        )
    {
        return (
            transactions[_txId].destination,
            transactions[_txId].value,
            transactions[_txId].data,
            transactions[_txId].executed,
            transactions[_txId].confirmationCount
        );
    }

    function getTransactionConfirmations(uint256 _txId) public view txExists(_txId) returns (address[] memory) {
        address[] memory confirmedBy = new address[](transactions[_txId].confirmationCount);
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (transactions[_txId].confirmations[owners[i]]) {
                confirmedBy[count] = owners[i];
                count++;
            }
        }
        return confirmedBy;
    }
}