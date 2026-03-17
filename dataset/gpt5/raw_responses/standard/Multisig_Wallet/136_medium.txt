// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    // Errors
    error NotOwner();
    error TxDoesNotExist();
    error AlreadyConfirmed();
    error NotConfirmed();
    error AlreadyExecuted();
    error InvalidThreshold();
    error OwnerExists();
    error OwnerDoesNotExist();
    error InvalidOwner();
    error InsufficientBalance();

    // Events
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txId);
    event RevokeConfirmation(address indexed owner, uint256 indexed txId);
    event ExecuteTransaction(uint256 indexed txId, bool success, bytes result);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint256 indexed threshold);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Only wallet");
        _;
    }

    modifier txExists(uint256 txId) {
        if (txId >= transactions.length) revert TxDoesNotExist();
        _;
    }

    modifier notExecuted(uint256 txId) {
        if (transactions[txId].executed) revert AlreadyExecuted();
        _;
    }

    modifier notConfirmed(uint256 txId) {
        if (isConfirmed[txId][msg.sender]) revert AlreadyConfirmed();
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) payable {
        if (_owners.length == 0) revert InvalidOwner();
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert InvalidOwner();
            if (isOwner[owner]) revert OwnerExists();
            isOwner[owner] = true;
            owners.push(owner);
        }
        if (_threshold == 0 || _threshold > owners.length) revert InvalidThreshold();
        threshold = _threshold;
        emit ThresholdChanged(_threshold);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    fallback() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // Transaction lifecycle
    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        txId = transactions.length;
        transactions.push(Transaction({to: to, value: value, data: data, executed: false, numConfirmations: 0}));
        emit SubmitTransaction(txId, to, value, data);
    }

    function confirmTransaction(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
        notConfirmed(txId)
    {
        isConfirmed[txId][msg.sender] = true;
        transactions[txId].numConfirmations += 1;
        emit ConfirmTransaction(msg.sender, txId);
    }

    function revokeConfirmation(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        if (!isConfirmed[txId][msg.sender]) revert NotConfirmed();
        isConfirmed[txId][msg.sender] = false;
        transactions[txId].numConfirmations -= 1;
        emit RevokeConfirmation(msg.sender, txId);
    }

    function executeTransaction(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        Transaction storage txn = transactions[txId];
        if (txn.numConfirmations < threshold) revert InvalidThreshold();
        if (address(this).balance < txn.value) revert InsufficientBalance();

        txn.executed = true;
        (bool success, bytes memory result) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Tx failed");
        emit ExecuteTransaction(txId, success, result);
    }

    // Owner and threshold management (must be executed via multisig as self-calls)
    function addOwner(address newOwner) external onlySelf {
        if (newOwner == address(0)) revert InvalidOwner();
        if (isOwner[newOwner]) revert OwnerExists();
        isOwner[newOwner] = true;
        owners.push(newOwner);
        emit OwnerAdded(newOwner);
        // No change to threshold here; must be adjusted via changeThreshold if desired.
    }

    function removeOwner(address owner) external onlySelf {
        if (!isOwner[owner]) revert OwnerDoesNotExist();
        isOwner[owner] = false;

        // Remove from owners array
        uint256 len = owners.length;
        for (uint256 i = 0; i < len; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[len - 1];
                owners.pop();
                break;
            }
        }

        // Ensure threshold remains valid; auto-adjust down if needed
        if (threshold > owners.length) {
            threshold = owners.length;
            emit ThresholdChanged(threshold);
        }

        emit OwnerRemoved(owner);
    }

    function changeThreshold(uint256 newThreshold) external onlySelf {
        if (newThreshold == 0 || newThreshold > owners.length) revert InvalidThreshold();
        threshold = newThreshold;
        emit ThresholdChanged(newThreshold);
    }

    // View helpers
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 txId)
        external
        view
        txExists(txId)
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations)
    {
        Transaction storage txn = transactions[txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.numConfirmations);
    }

    function isTxConfirmedBy(uint256 txId, address owner) external view returns (bool) {
        return isConfirmed[txId][owner];
    }
}