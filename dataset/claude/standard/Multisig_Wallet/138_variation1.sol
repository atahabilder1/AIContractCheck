// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultisigWallet {
    enum TxType { EthTransfer, ContractCall, OwnerChange }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        TxType txType;
        bool executed;
        uint256 approvalCount;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public ethTransferThreshold;
    uint256 public contractCallThreshold;
    uint256 public ownerChangeThreshold;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    event TransactionSubmitted(uint256 indexed txId, TxType txType, address to, uint256 value);
    event TransactionApproved(uint256 indexed txId, address indexed owner);
    event ApprovalRevoked(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }

    constructor(
        address[] memory _owners,
        uint256 _ethTransferThreshold,
        uint256 _contractCallThreshold,
        uint256 _ownerChangeThreshold
    ) {
        require(_owners.length > 0, "no owners");
        require(_ethTransferThreshold > 0 && _ethTransferThreshold <= _owners.length, "invalid eth threshold");
        require(_contractCallThreshold > 0 && _contractCallThreshold <= _owners.length, "invalid call threshold");
        require(_ownerChangeThreshold > 0 && _ownerChangeThreshold <= _owners.length, "invalid owner threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "zero address");
            require(!isOwner[owner], "duplicate owner");
            isOwner[owner] = true;
            owners.push(owner);
        }

        ethTransferThreshold = _ethTransferThreshold;
        contractCallThreshold = _contractCallThreshold;
        ownerChangeThreshold = _ownerChangeThreshold;
    }

    receive() external payable {}

    function submit(address _to, uint256 _value, bytes calldata _data, TxType _txType) external onlyOwner {
        if (_txType == TxType.OwnerChange) {
            require(_to == address(this), "owner change must target self");
        }
        uint256 txId = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            txType: _txType,
            executed: false,
            approvalCount: 0
        }));
        emit TransactionSubmitted(txId, _txType, _to, _value);
    }

    function approve(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(!approved[_txId][msg.sender], "already approved");
        approved[_txId][msg.sender] = true;
        transactions[_txId].approvalCount++;
        emit TransactionApproved(_txId, msg.sender);
    }

    function revoke(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "not approved");
        approved[_txId][msg.sender] = false;
        transactions[_txId].approvalCount--;
        emit ApprovalRevoked(_txId, msg.sender);
    }

    function execute(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        Transaction storage txn = transactions[_txId];
        require(txn.approvalCount >= getThreshold(txn.txType), "not enough approvals");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "tx failed");

        emit TransactionExecuted(_txId);
    }

    function addOwner(address _owner) external {
        require(msg.sender == address(this), "only via multisig");
        require(_owner != address(0), "zero address");
        require(!isOwner[_owner], "already owner");

        isOwner[_owner] = true;
        owners.push(_owner);
        emit OwnerAdded(_owner);
    }

    function removeOwner(address _owner) external {
        require(msg.sender == address(this), "only via multisig");
        require(isOwner[_owner], "not owner");
        require(owners.length - 1 >= ownerChangeThreshold, "would break threshold");
        require(owners.length - 1 >= contractCallThreshold, "would break threshold");
        require(owners.length - 1 >= ethTransferThreshold, "would break threshold");

        isOwner[_owner] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        emit OwnerRemoved(_owner);
    }

    function updateThresholds(
        uint256 _ethTransferThreshold,
        uint256 _contractCallThreshold,
        uint256 _ownerChangeThreshold
    ) external {
        require(msg.sender == address(this), "only via multisig");
        require(_ethTransferThreshold > 0 && _ethTransferThreshold <= owners.length, "invalid eth threshold");
        require(_contractCallThreshold > 0 && _contractCallThreshold <= owners.length, "invalid call threshold");
        require(_ownerChangeThreshold > 0 && _ownerChangeThreshold <= owners.length, "invalid owner threshold");

        ethTransferThreshold = _ethTransferThreshold;
        contractCallThreshold = _contractCallThreshold;
        ownerChangeThreshold = _ownerChangeThreshold;
    }

    function getThreshold(TxType _txType) public view returns (uint256) {
        if (_txType == TxType.EthTransfer) return ethTransferThreshold;
        if (_txType == TxType.ContractCall) return contractCallThreshold;
        return ownerChangeThreshold;
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }
}