```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleMultisig {
    event Deposit(address indexed sender, uint256 amount);
    event Submission(uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event Confirmation(address indexed owner, uint256 indexed txIndex);
    event Revocation(address indexed owner, uint256 indexed txIndex);
    event Execution(uint256 indexed txIndex);
    event ExecutionFailure(uint256 indexed txIndex);

    // Array of the 3 owners
    address[3] public owners;
    // Mapping to quickly check if an address is an owner
    mapping(address => bool) public isOwner;
    // The number of confirmations required for a transaction to be executed (fixed at 2)
    uint256 public required;

    // Struct to represent a transaction
    struct Transaction {
        address to;      // Recipient address
        uint256 value;   // Amount of Ether to send (in wei)
        bytes data;      // Calldata for contract interaction (empty for plain Ether transfer)
        bool executed;   // True if the transaction has been executed
        uint256 numConfirmations; // Current number of confirmations
    }

    // Array of all submitted transactions
    Transaction[] public transactions;
    // Mapping from transaction index to owner address to confirmation status
    mapping(uint256 => mapping(address => bool)) public confirmations;

    // Modifier to restrict function access to owners only
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    // Modifier to check if a transaction exists
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    // Modifier to check if a transaction has not yet been executed
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    // Modifier to check if the sender has not yet confirmed a transaction
    modifier notConfirmed(uint256 _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed by sender");
        _;
    }

    // Modifier to check if the sender has already confirmed a transaction
    modifier alreadyConfirmed(uint256 _txIndex) {
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed by sender");
        _;
    }

    /// @notice Constructor to initialize the 3 owners of the multisig wallet.
    /// @param _owner1 The address of the first owner.
    /// @param _owner2 The address of the second owner.
    ///