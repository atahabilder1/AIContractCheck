// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GasOptimizedMultiSig {
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    mapping(uint256 => Transaction) public transactions;
    address[] public owners;
    uint256 public requiredConfirmations;
    uint256 public transactionCount;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);

    modifier onlyOwner(uint256 _transactionId) {
        require(_isOwner(msg.sender), "Not an owner");
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "Transaction already executed");
        _;
    }

    modifier isConfirmedByOwner(uint256 _transactionId) {
        require(isConfirmed[_transactionId][msg.sender], "Not confirmed by owner");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners cannot be empty");
        require(_requiredConfirmations > 0, "Required confirmations must be greater than 0");
        require(_requiredConfirmations <= _owners.length, "Required confirmations exceed owners count");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Owner cannot be the zero address");
            owners.push(_owners[i]);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    function _isOwner(address _addr) internal view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _addr) {
                return true;
            }
        }
        return false;
    }

    function submitTransaction(address _destination, uint256 _value, bytes memory _data) public onlyOwner(0) returns (uint256 transactionId) {
        require(_destination != address(0), "Destination cannot be the zero address");
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false
        });
        transactionCount++;
        emit Submission(transactionId);
        return transactionId;
    }

    function confirmTransaction(uint256 _transactionId) public onlyOwner(_transactionId) notExecuted(_transactionId) {
        require(!isConfirmed[_transactionId][msg.sender], "Transaction already confirmed by sender");
        isConfirmed[_transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, _transactionId);

        if (getConfirmationsCount(_transactionId) >= requiredConfirmations) {
            _executeTransaction(_transactionId);
        }
    }

    function revokeConfirmation(uint256 _transactionId) public onlyOwner(_transactionId) isConfirmedByOwner(_transactionId) notExecuted(_transactionId) {
        isConfirmed[_transactionId][msg.sender] = false;
        emit Revocation(msg.sender, _transactionId);
    }

    function executeTransaction(uint256 _transactionId) public onlyOwner(_transactionId) notExecuted(_transactionId) {
        require(getConfirmationsCount(_transactionId) >= requiredConfirmations, "Not enough confirmations to execute");
        _executeTransaction(_transactionId);
    }

    function _executeTransaction(uint256 _transactionId) internal {
        Transaction storage txn = transactions[_transactionId];
        txn.executed = true;
        (bool success, ) = txn.destination.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");
        emit Execution(_transactionId);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getConfirmationsCount(uint256 _transactionId) public view returns (uint256 count) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (isConfirmed[_transactionId][owners[i]]) {
                count++;
            }
        }
    }

    receive() external payable {}
}