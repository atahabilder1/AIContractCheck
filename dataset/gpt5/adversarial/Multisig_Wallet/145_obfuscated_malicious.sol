// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MultiSigWallet {
    // Owners and confirmations
    address[] private _owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    // Admin (emergency)
    address public admin;

    // Pausable
    bool public paused;

    // Reentrancy guard
    bool private _entered;

    // Transactions
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // Events
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex, bytes returnData);
    event Paused(address indexed admin);
    event Unpaused(address indexed admin);
    event EmergencyWithdrawal(address indexed admin, address indexed to, uint256 amount);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    modifier nonReentrant() {
        require(!_entered, "reentrancy");
        _entered = true;
        _;
        _entered = false;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "only wallet");
        _;
    }

    constructor(address[] memory owners_, uint256 required_, address admin_) payable {
        require(owners_.length > 0, "owners required");
        require(required_ > 0 && required_ <= owners_.length, "invalid required");
        require(admin_ != address(0), "admin zero");

        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            require(owner != address(0), "owner zero");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            _owners.push(owner);
        }

        required = required_;
        admin = admin_;
    }

    // Receive ETH
    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value, address(this).balance);
        }
    }

    fallback() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value, address(this).balance);
        }
    }

    // View helpers
    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        external
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage txn = transactions[_txIndex];
        return (txn.to, txn.value, txn.data, txn.executed, txn.numConfirmations);
    }

    // Core multisig functions (paused when emergency pause is active)
    function submitTransaction(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        whenNotPaused
    {
        require(to != address(0), "to zero");

        transactions.push(
            Transaction({
                to: to,
                value: value,
                data: data,
                executed: false,
                numConfirmations: 0
            })
        );
        uint256 txIndex = transactions.length - 1;

        emit SubmitTransaction(msg.sender, txIndex, to, value, data);
    }

    function confirmTransaction(uint256 _txIndex)
        external
        onlyOwner
        whenNotPaused
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage txn = transactions[_txIndex];
        isConfirmed[_txIndex][msg.sender] = true;
        txn.numConfirmations += 1;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        external
        onlyOwner
        whenNotPaused
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");
        Transaction storage txn = transactions[_txIndex];

        isConfirmed[_txIndex][msg.sender] = false;
        txn.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        external
        onlyOwner
        whenNotPaused
        txExists(_txIndex)
        notExecuted(_txIndex)
        nonReentrant
    {
        Transaction storage txn = transactions[_txIndex];
        require(txn.numConfirmations >= required, "insufficient confirmations");

        txn.executed = true;

        (bool success, bytes memory ret) = txn.to.call{value: txn.value}(txn.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex, ret);
    }

    // Emergency admin functions (not affected by pause)
    function pause() external onlyAdmin {
        require(!paused, "already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyAdmin {
        require(paused, "not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdrawAll(address payable to) external onlyAdmin nonReentrant {
        require(to != address(0), "to zero");
        uint256 amount = address(this).balance;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "withdraw failed");
        emit EmergencyWithdrawal(msg.sender, to, amount);
    }

    // Admin management via multisig (only wallet can change)
    function changeAdmin(address newAdmin) external onlySelf {
        require(newAdmin != address(0), "admin zero");
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }
}