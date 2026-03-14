// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed owner, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    
    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        uint8 requiredApprovals;
        uint8 transactionType; // 0 = ETH transfer, 1 = contract call, 2 = owner change
    }
    
    mapping(uint256 => mapping(address => bool)) public confirmations;
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint8 public numOwners;
    uint256 public transactionCount;

    uint8 constant ETH_TRANSFER_APPROVALS = 2;
    uint8 constant CONTRACT_CALL_APPROVALS = 3;
    uint8 constant OWNER_CHANGE_APPROVALS = 4;

    Transaction[] public transactions;

    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet can execute");
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "Owner does not exist");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier confirmed(uint256 transactionId, address owner) {
        require(confirmations[transactionId][owner], "Transaction not confirmed by owner");
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner) {
        require(!confirmations[transactionId][owner], "Transaction already confirmed");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    modifier validRequirement(uint8 ownerCount, uint8 _required) {
        require(ownerCount >= _required && _required != 0 && ownerCount != 0, "Invalid requirement");
        _;
    }

    constructor(address[] memory _owners) {
        require(_owners.length > 0, "Owners required");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0) && !isOwner[_owners[i]], "Invalid owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        numOwners = uint8(_owners.length);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address destination, uint256 value, bytes memory data, uint8 transactionType)
        public
        ownerExists(msg.sender)
        returns (uint256)
    {
        uint8 requiredApprovals;
        if (transactionType == 0) {
            requiredApprovals = ETH_TRANSFER_APPROVALS;
        } else if (transactionType == 1) {
            requiredApprovals = CONTRACT_CALL_APPROVALS;
        } else if (transactionType == 2) {
            requiredApprovals = OWNER_CHANGE_APPROVALS;
        } else {
            revert("Invalid transaction type");
        }
        
        uint256 transactionId = transactions.length;
        transactions.push(Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false,
            requiredApprovals: requiredApprovals,
            transactionType: transactionType
        }));
        emit Submission(transactionId);
        confirmTransaction(transactionId);
        return transactionId;
    }

    function confirmTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    function executeTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        if (isConfirmed(transactionId)) {
            Transaction storage txn = transactions[transactionId];
            txn.executed = true;
            if (externalCall(txn.destination, txn.value, txn.data)) {
                emit Execution(transactionId);
            } else {
                emit ExecutionFailure(transactionId);
                txn.executed = false;
            }
        }
    }

    function isConfirmed(uint256 transactionId) public view returns (bool) {
        uint8 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
            if (count == transactions[transactionId].requiredApprovals) {
                return true;
            }
        }
        return false;
    }

    function externalCall(address destination, uint256 value, bytes memory data) internal returns (bool) {
        (bool success, ) = destination.call{value: value}(data);
        return success;
    }

    function addOwner(address owner) public onlyWallet {
        require(owner != address(0) && !isOwner[owner], "Invalid owner");
        isOwner[owner] = true;
        owners.push(owner);
        numOwners++;
        emit OwnerAddition(owner);
    }

    function removeOwner(address owner) public onlyWallet ownerExists(owner) {
        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();
        numOwners--;
        emit OwnerRemoval(owner);
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 transactionId)
        public
        view
        returns (address destination, uint256 value, bytes memory data, bool executed, uint8 requiredApprovals, uint8 transactionType)
    {
        Transaction storage txn = transactions[transactionId];
        return (txn.destination, txn.value, txn.data, txn.executed, txn.requiredApprovals, txn.transactionType);
    }
}