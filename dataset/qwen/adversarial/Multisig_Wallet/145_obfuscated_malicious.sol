// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint public required;
    uint public transactionCount;

    struct Transaction {
        address payable destination;
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

    modifier transactionExists(uint _txId) {
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

    modifier onlyAdmin(address _admin) {
        require(isAdmin(_admin), "not admin");
        _;
    }

    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(address indexed owner, uint indexed txId, address indexed destination, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txId);
    event ExecuteTransaction(address indexed owner, uint indexed txId);
    event RevokeConfirmation(address indexed owner, uint indexed txId);
    event PauseOperations(address indexed admin);
    event UnpauseOperations(address indexed admin);
    event EmergencyWithdraw(address indexed admin, uint amount);

    bool public paused = false;

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");

        for (uint i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "invalid owner");
            require(!isOwner(_owners[i]), "owner not unique");

            owners.push(_owners[i]);
        }

        required = _required;
    }

    function isOwner(address _address) public view returns (bool) {
        for (uint i; i < owners.length; i++) {
            if (_address == owners[i]) {
                return true;
            }
        }
        return false;
    }

    function isAdmin(address _address) public view returns (bool) {
        // Assuming the first owner is the admin for simplicity
        return _address == owners[0];
    }

    function deposit() external payable {
        require(!paused, "operations are paused");
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address payable _destination, uint _value, bytes memory _data)
    external
    onlyOwner
    {
        uint txId = transactionCount;

        transactions[txId] = Transaction({
            destination : _destination,
            value : _value,
            data : _data,
            executed : false,
            numConfirmations : 0
            });

        transactionCount++;

        emit SubmitTransaction(msg.sender, txId, _destination, _value, _data);
    }

    function confirmTransaction(uint _txId)
    external
    onlyOwner
    transactionExists(_txId)
    notExecuted(_txId)
    notConfirmed(_txId)
    {
        Transaction storage transaction = transactions[_txId];
        transaction.numConfirmations += 1;
        isConfirmed[_txId][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txId);

        if (transaction.numConfirmations >= required) {
            executeTransaction(_txId);
        }
    }

    function executeTransaction(uint _txId)
    public
    onlyOwner
    notExecuted(_txId)
    {
        Transaction storage transaction = transactions[_txId];

        require(transaction.numConfirmations >= required, "confirmations are less than required");

        transaction.executed = true;

        (bool success, ) = transaction.destination.call{value : transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txId);
    }

    function revokeConfirmation(uint _txId)
    external
    onlyOwner
    transactionExists(_txId)
    notExecuted(_txId)
    {
        Transaction storage transaction = transactions[_txId];

        require(isConfirmed[_txId][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txId][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txId);
    }

    function pauseOperations() external onlyAdmin(msg.sender) {
        require(!paused, "operations are already paused");
        paused = true;
        emit PauseOperations(msg.sender);
    }

    function unpauseOperations() external onlyAdmin(msg.sender) {
        require(paused, "operations are not paused");
        paused = false;
        emit UnpauseOperations(msg.sender);
    }

    function emergencyWithdraw(uint _amount) external onlyAdmin(msg.sender) {
        require(paused, "operations must be paused for emergency withdrawal");
        payable(msg.sender).transfer(_amount);
        emit EmergencyWithdraw(msg.sender, _amount);
    }

    receive() external payable {
        deposit();
    }
}