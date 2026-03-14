// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    // --- State Variables ---
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required; // Number of approvals required for a transaction to execute

    uint256 public transactionCount; // Total number of transactions ever submitted

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
        mapping(address => bool) confirmed; // Tracks which owner has confirmed this transaction
    }

    mapping(uint256 => Transaction) public transactions;

    // --- Events ---
    event Deposit(address indexed sender, uint256 amount);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed destination,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Multisig: Not an owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactionCount, "Multisig: Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Multisig: Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!transactions[_txIndex].confirmed[msg.sender], "Multisig: Transaction already confirmed by sender");
        _;
    }

    modifier confirmed(uint256 _txIndex) {
        require(transactions[_txIndex].confirmed[msg.sender], "Multisig: Transaction not confirmed by sender");
        _;
    }

    // --- Constructor ---
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Multisig: Owners required");
        require(_required > 0 && _required <= _owners.length, "Multisig: Invalid required number of confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Multisig: Invalid owner address");
            require(!isOwner[owner], "Multisig: Duplicate owner"); // Prevent duplicate owners
            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    // --- Fallback/Receive Function ---
    // Allows the contract to receive Ether.
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // --- Core Functions ---

    /**
     * @dev Submits a new transaction to be approved by owners.
     * @param _destination The address of the recipient or contract to interact with.
     * @param _value The amount of Ether to send with the transaction.
     * @param _data The calldata for contract interaction, or empty bytes for simple Ether transfer.
     * @return txIndex The index of the newly submitted transaction.
     */
    function submitTransaction(
        address _destination,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner returns (uint256 txIndex) {
        txIndex = transactionCount;
        transactions[txIndex] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        });
        transactionCount++;

        emit SubmitTransaction(msg.sender, txIndex, _destination, _value, _data);
        return txIndex;
    }

    /**
     * @dev Confirms an existing transaction.
     *      An owner can only confirm a transaction once.
     * @param _txIndex The index of the transaction to confirm.
     */
    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmed[msg.sender] = true;
        transaction.numConfirmations++;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev Revokes a confirmation for an existing transaction.
     *      An owner can only revoke their own confirmation.
     * @param _txIndex The index of the transaction to revoke confirmation from.
     */
    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        confirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmed[msg.sender] = false;
        transaction.numConfirmations--;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /**
     * @dev Executes a transaction if it has met the required number of confirmations.
     * @param _txIndex The index of the transaction to execute.
     */
    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.numConfirmations >= required, "Multisig: Not enough confirmations");

        transaction.executed = true; // Mark as executed BEFORE the call to prevent reentrancy issues

        (bool success, ) = transaction.destination.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Multisig: Transaction execution failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    // --- View Functions ---

    /**
     * @dev Returns the list of all owners.
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev Returns the total number of transactions ever submitted.
     */
    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    /**
     * @dev Returns the number of confirmations for a given transaction.
     * @param _txIndex The index of the transaction.
     */
    function getConfirmationCount(uint256 _txIndex) public view returns (uint256) {
        require(_txIndex < transactionCount, "Multisig: Transaction does not exist");
        return transactions[_txIndex].numConfirmations;
    }

    /**
     * @dev Checks if a specific owner has confirmed a specific transaction.
     * @param _txIndex The index of the transaction.
     * @param _owner The address of the owner to check.
     */
    function isConfirmed(uint256 _txIndex, address _owner) public view returns (bool) {
        require(_txIndex < transactionCount, "Multisig: Transaction does not exist");
        return transactions[_txIndex].confirmed[_owner];
    }
}