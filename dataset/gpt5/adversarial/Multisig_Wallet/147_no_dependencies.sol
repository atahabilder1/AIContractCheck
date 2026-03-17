// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 value);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed owner, uint256 indexed transactionId);
    event Revocation(address indexed owner, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);

    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmedBy;

    bool private locked;

    modifier nonReentrant() {
        require(!locked, "REENTRANT");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet");
        _;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner], "Owner exists");
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "Owner missing");
        _;
    }

    modifier txExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Tx missing");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Tx executed");
        _;
    }

    modifier notConfirmed(uint256 transactionId) {
        require(!confirmedBy[transactionId][msg.sender], "Already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Zero owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAddition(owner);
        }
        require(_required > 0 && _required <= owners.length, "Invalid requirement");
        required = _required;
        emit RequirementChange(_required);
    }

    receive() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    fallback() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (uint256 transactionId)
    {
        transactionId = _addTransaction(to, value, data);
        emit Submission(transactionId);
        _confirmTransaction(transactionId, msg.sender);
    }

    function confirmTransaction(uint256 transactionId)
        external
        onlyOwner
        txExists(transactionId)
        notExecuted(transactionId)
        notConfirmed(transactionId)
    {
        _confirmTransaction(transactionId, msg.sender);
    }

    function revokeConfirmation(uint256 transactionId)
        external
        onlyOwner
        txExists(transactionId)
        notExecuted(transactionId)
    {
        require(confirmedBy[transactionId][msg.sender], "Not confirmed");
        confirmedBy[transactionId][msg.sender] = false;
        transactions[transactionId].confirmations -= 1;
        emit Revocation(msg.sender, transactionId);
    }

    function executeTransaction(uint256 transactionId)
        external
        onlyOwner
        txExists(transactionId)
        notExecuted(transactionId)
        nonReentrant
    {
        require(transactions[transactionId].confirmations >= required, "Insufficient confirmations");
        Transaction storage txn = transactions[transactionId];
        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (success) {
            emit Execution(transactionId);
        } else {
            txn.executed = false;
            emit ExecutionFailure(transactionId);
        }
    }

    function _addTransaction(address to, uint256 value, bytes calldata data) internal returns (uint256 transactionId) {
        transactions.push(Transaction({to: to, value: value, data: data, executed: false, confirmations: 0}));
        transactionId = transactions.length - 1;
    }

    function _confirmTransaction(uint256 transactionId, address owner) internal {
        confirmedBy[transactionId][owner] = true;
        transactions[transactionId].confirmations += 1;
        emit Confirmation(owner, transactionId);
    }

    // Owner management - callable only via multisig (submit a tx to address(this) with encoded data)
    function addOwner(address owner) external onlyWallet ownerDoesNotExist(owner) {
        require(owner != address(0), "Zero owner");
        isOwner[owner] = true;
        owners.push(owner);
        require(required <= owners.length, "Adjust requirement");
        emit OwnerAddition(owner);
    }

    function removeOwner(address owner) external onlyWallet ownerExists(owner) {
        isOwner[owner] = false;

        // remove from owners array
        uint256 len = owners.length;
        for (uint256 i = 0; i < len; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[len - 1];
                owners.pop();
                break;
            }
        }

        if (required > owners.length) {
            required = owners.length;
            emit RequirementChange(required);
        }
        emit OwnerRemoval(owner);
    }

    function replaceOwner(address owner, address newOwner)
        external
        onlyWallet
        ownerExists(owner)
        ownerDoesNotExist(newOwner)
    {
        require(newOwner != address(0), "Zero owner");
        // update mapping first
        isOwner[owner] = false;
        isOwner[newOwner] = true;

        // replace in array
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        }
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    function changeRequirement(uint256 _required) external onlyWallet {
        require(_required > 0 && _required <= owners.length, "Invalid requirement");
        required = _required;
        emit RequirementChange(_required);
    }

    // View helpers
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 transactionId)
        external
        view
        txExists(transactionId)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations
        )
    {
        Transaction storage txn = transactions[transactionId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }

    function getConfirmationCount(uint256 transactionId)
        external
        view
        txExists(transactionId)
        returns (uint256)
    {
        return transactions[transactionId].confirmations;
    }

    function isConfirmed(uint256 transactionId, address owner)
        external
        view
        txExists(transactionId)
        ownerExists(owner)
        returns (bool)
    {
        return confirmedBy[transactionId][owner];
    }
}