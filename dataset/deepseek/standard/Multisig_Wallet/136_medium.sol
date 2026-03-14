// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint256 public threshold;
    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
        mapping(address => bool) approvals;
    }

    event Submission(uint256 indexed transactionId);
    event Approval(uint256 indexed transactionId, address indexed owner);
    event Execution(uint256 indexed transactionId);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);

    modifier onlyOwner() {
        bool isOwner = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "MultisigWallet: caller is not an owner");
        _;
    }

    modifier validThreshold() {
        require(threshold <= owners.length, "MultisigWallet: threshold exceeds number of owners");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactionCount, "MultisigWallet: transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "MultisigWallet: transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "MultisigWallet: at least one owner is required");
        require(_threshold > 0 && _threshold <= _owners.length, "MultisigWallet: invalid threshold");
        owners = _owners;
        threshold = _threshold;
    }

    function addOwner(address newOwner) public onlyOwner validThreshold {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == newOwner) {
                revert("MultisigWallet: owner already exists");
            }
        }
        owners.push(newOwner);
        emit OwnerAddition(newOwner);
    }

    function removeOwner(address oldOwner) public onlyOwner validThreshold {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == oldOwner) {
                for (uint256 j = i; j < owners.length - 1; j++) {
                    owners[j] = owners[j + 1];
                }
                owners.pop();
                emit OwnerRemoval(oldOwner);
                break;
            }
        }
    }

    function submitTransaction(address to, uint256 value, bytes memory data) public onlyOwner {
        uint256 transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            approvalCount: 0
        });
        transactionCount++;
        emit Submission(transactionId);
    }

    function approveTransaction(uint256 transactionId) public onlyOwner transactionExists(transactionId) notExecuted(transactionId) {
        require(!transactions[transactionId].approvals[msg.sender], "MultisigWallet: transaction already approved");
        transactions[transactionId].approvals[msg.sender] = true;
        transactions[transactionId].approvalCount++;
        emit Approval(transactionId, msg.sender);
    }

    function executeTransaction(uint256 transactionId) public onlyOwner transactionExists(transactionId) notExecuted(transactionId) {
        require(transactions[transactionId].approvalCount >= threshold, "MultisigWallet: approval count does not meet threshold");
        Transaction storage transaction = transactions[transactionId];
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "MultisigWallet: transaction execution failed");
        transaction.executed = true;
        emit Execution(transactionId);
    }
}