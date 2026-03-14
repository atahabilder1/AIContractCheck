// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint public required;
    uint public transactionCount;
    
    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }
    
    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public isConfirmed;
    
    modifier onlyOwner() {
        require(isOwner(msg.sender), "not owner");
        _;
    }
    
    modifier txExists(uint _txId) {
        require(transactions[_txId].destination != address(0), "tx does not exist");
        _;
    }
    
    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }
    
    modifier notConfirmed(uint _txId) {
        require(!isConfirmed[_txId][msg.sender], "tx already confirmed");
        _;
    }
    
    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");
        
        for (uint i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "invalid owner");
            require(!isOwner(_owners[i]), "owner is not unique");
            
            owners.push(_owners[i]);
        }
        
        required = _required;
    }
    
    function isOwner(address _addr) public view returns (bool) {
        for (uint i; i < owners.length; i++) {
            if (_addr == owners[i]) {
                return true;
            }
        }
        return false;
    }
    
    function submitTransaction(address _destination, uint _value, bytes memory _data)
        public
        onlyOwner
    {
        uint txId = transactionCount;
        transactions[txId] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        });
        transactionCount++;
        emit SubmitTransaction(msg.sender, txId, _destination, _value, _data);
    }
    
    function confirmTransaction(uint _txId)
        public
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
        notConfirmed(_txId)
    {
        Transaction storage transaction = transactions[_txId];
        transaction.numConfirmations += 1;
        isConfirmed[_txId][msg.sender] = true;
        
        if (transaction.numConfirmations >= required) {
            executeTransaction(_txId);
        }
        
        emit ConfirmTransaction(msg.sender, _txId);
    }
    
    function executeTransaction(uint _txId) public txExists(_txId) notExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];
        
        require(transaction.numConfirmations >= required, "cannot execute tx");
        
        transaction.executed = true;
        
        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");
        
        emit ExecuteTransaction(msg.sender, _txId);
    }
    
    function revokeConfirmation(uint _txId)
        public
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        Transaction storage transaction = transactions[_txId];
        
        require(isConfirmed[_txId][msg.sender], "tx not confirmed");
        
        transaction.numConfirmations -= 1;
        isConfirmed[_txId][msg.sender] = false;
        
        emit RevokeConfirmation(msg.sender, _txId);
    }
    
    receive() external payable {}
    
    event SubmitTransaction(
        address indexed owner,
        uint indexed txId,
        address indexed destination,
        uint value,
        bytes data
    );
    
    event ConfirmTransaction(address indexed owner, uint indexed txId);
    
    event RevokeConfirmation(address indexed owner, uint indexed txId);
    
    event ExecuteTransaction(address indexed owner, uint indexed txId);
}