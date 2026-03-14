// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MultisigWallet is Ownable, Pausable {

    struct Transaction {
        address payable destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;
    uint256 public requiredConfirmations;

    mapping(uint256 => mapping(address => bool)) public confirmations;
    mapping(address => bool) public isOwner;

    address[] public owners;

    event TransactionProposed(uint256 indexed transactionId, address indexed proposer, address indexed destination, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed transactionId, address indexed owner);
    event TransactionExecuted(uint256 indexed transactionId);
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event RequiredConfirmationsChanged(uint256 newRequiredConfirmations);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultisigWallet: Not an owner");
        _;
    }

    modifier onlyOwners() {
        require(owners.length > 0, "MultisigWallet: No owners");
        require(isOwner[msg.sender], "MultisigWallet: Not an owner");
        _;
    }

    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId < transactionCount, "MultisigWallet: Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "MultisigWallet: Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) Ownable() {
        require(_owners.length > 0, "MultisigWallet: Owners array cannot be empty");
        require(_requiredConfirmations > 0, "MultisigWallet: Required confirmations must be greater than 0");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "MultisigWallet: Owner cannot be the zero address");
            require(!isOwner[owner], "MultisigWallet: Duplicate owner");
            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
        transactionCount = 0;
    }

    fallback() external payable {}
    receive() external payable {}

    function proposeTransaction(address payable _destination, uint256 _value, bytes calldata _data) external onlyOwners whenNotPaused {
        require(_destination != address(0), "MultisigWallet: Destination cannot be the zero address");

        Transaction storage newTransaction = transactions[transactionCount];
        newTransaction.destination = _destination;
        newTransaction.value = _value;
        newTransaction.data = _data;
        newTransaction.executed = false;

        emit TransactionProposed(transactionCount, msg.sender, _destination, _value, _data);
        transactionCount++;
    }

    function confirmTransaction(uint256 _transactionId) external onlyOwners whenNotPaused transactionExists(_transactionId) notExecuted(_transactionId) {
        require(!confirmations[_transactionId][msg.sender], "MultisigWallet: Transaction already confirmed by this owner");

        confirmations[_transactionId][msg.sender] = true;
        emit TransactionConfirmed(_transactionId, msg.sender);

        uint256 currentConfirmations = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_transactionId][owners[i]]) {
                currentConfirmations++;
            }
        }

        if (currentConfirmations >= requiredConfirmations) {
            executeTransaction(_transactionId);
        }
    }

    function executeTransaction(uint256 _transactionId) public transactionExists(_transactionId) notExecuted(_transactionId) {
        require(owners.length > 0, "MultisigWallet: No owners");
        uint256 currentConfirmations = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_transactionId][owners[i]]) {
                currentConfirmations++;
            }
        }
        require(currentConfirmations >= requiredConfirmations, "MultisigWallet: Not enough confirmations");

        Transaction storage currentTransaction = transactions[_transactionId];
        currentTransaction.executed = true;

        (bool success, ) = currentTransaction.destination.call{value: currentTransaction.value}(currentTransaction.data);
        require(success, "MultisigWallet: Transaction execution failed");

        emit TransactionExecuted(_transactionId);
    }

    function revokeConfirmation(uint256 _transactionId) external onlyOwners whenNotPaused transactionExists(_transactionId) notExecuted(_transactionId) {
        require(confirmations[_transactionId][msg.sender], "MultisigWallet: Transaction not confirmed by this owner");
        confirmations[_transactionId][msg.sender] = false;
        // No event for revocation, as it might spam events and is less critical than confirmation.
    }

    function changeRequiredConfirmations(uint256 _newRequiredConfirmations) external onlyOwner whenNotPaused {
        require(_newRequiredConfirmations > 0, "MultisigWallet: Required confirmations must be greater than 0");
        require(_newRequiredConfirmations <= owners.length, "MultisigWallet: Required confirmations cannot exceed the number of owners");
        requiredConfirmations = _newRequiredConfirmations;
        emit RequiredConfirmationsChanged(_newRequiredConfirmations);
    }

    function addOwner(address _newOwner) external onlyOwner whenNotPaused {
        require(_newOwner != address(0), "MultisigWallet: Owner cannot be the zero address");
        require(!isOwner[_newOwner], "MultisigWallet: Duplicate owner");
        isOwner[_newOwner] = true;
        owners.push(_newOwner);
        emit OwnerAdded(_newOwner);
    }

    function removeOwner(address _ownerToRemove) external onlyOwner whenNotPaused {
        require(_ownerToRemove != address(0), "MultisigWallet: Owner cannot be the zero address");
        require(isOwner[_ownerToRemove], "MultisigWallet: Owner not found");
        require(owners.length > 1, "MultisigWallet: Cannot remove the last owner");
        require(requiredConfirmations <= owners.length - 1, "MultisigWallet: Cannot remove owner if required confirmations exceed new owner count");

        isOwner[_ownerToRemove] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _ownerToRemove) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        emit OwnerRemoved(_ownerToRemove);
    }

    // Admin emergency functions
    function emergencyWithdrawAll() external onlyOwner {
        require(address(this).balance > 0, "MultisigWallet: No funds to withdraw");
        payable(owner()).transfer(address(this).balance);
    }

    function emergencyPause() external onlyOwner {
        _pause();
    }

    function emergencyUnpause() external onlyOwner {
        _unpause();
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 _transactionId) public view returns (address destination, uint256 value, bytes memory data, bool executed) {
        Transaction storage t = transactions[_transactionId];
        return (t.destination, t.value, t.data, t.executed);
    }

    function getConfirmationCount(uint256 _transactionId) public view transactionExists(_transactionId) returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_transactionId][owners[i]]) {
                count++;
            }
        }
        return count;
    }

    function isConfirmed(uint256 _transactionId, address _owner) public view transactionExists(_transactionId) returns (bool) {
        return confirmations[_transactionId][_owner];
    }
}