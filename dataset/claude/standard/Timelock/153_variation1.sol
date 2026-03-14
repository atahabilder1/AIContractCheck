// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EmergencyTimelock {
    uint256 public constant MIN_DELAY = 2 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant EMERGENCY_DELAY = 1 hours;
    uint256 public constant SUPERMAJORITY_NUMERATOR = 75;
    uint256 public constant SUPERMAJORITY_DENOMINATOR = 100;

    address public admin;
    address[] public guardians;
    mapping(address => bool) public isGuardian;

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 eta;
        bool executed;
        bool emergency;
        uint256 approvalCount;
    }

    mapping(bytes32 => Transaction) public transactions;
    mapping(bytes32 => mapping(address => bool)) public approvals;

    event TransactionQueued(bytes32 indexed txId, address target, uint256 value, bytes data, uint256 eta);
    event EmergencyQueued(bytes32 indexed txId, address target, uint256 value, bytes data, uint256 eta);
    event TransactionExecuted(bytes32 indexed txId);
    event TransactionCancelled(bytes32 indexed txId);
    event EmergencyApproved(bytes32 indexed txId, address guardian, uint256 approvalCount);
    event GuardianAdded(address guardian);
    event GuardianRemoved(address guardian);
    event AdminTransferred(address newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "not guardian");
        _;
    }

    modifier onlyThis() {
        require(msg.sender == address(this), "not timelock");
        _;
    }

    constructor(address _admin, address[] memory _guardians) {
        require(_guardians.length >= 3, "need at least 3 guardians");
        admin = _admin;

        for (uint256 i = 0; i < _guardians.length; i++) {
            address g = _guardians[i];
            require(g != address(0), "zero address");
            require(!isGuardian[g], "duplicate guardian");
            isGuardian[g] = true;
            guardians.push(g);
        }
    }

    function queueTransaction(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _delay
    ) external onlyAdmin returns (bytes32) {
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY, "invalid delay");

        uint256 eta = block.timestamp + _delay;
        bytes32 txId = _getTxId(_target, _value, _data, eta, false);
        require(transactions[txId].eta == 0, "already queued");

        transactions[txId] = Transaction({
            target: _target,
            value: _value,
            data: _data,
            eta: eta,
            executed: false,
            emergency: false,
            approvalCount: 0
        });

        emit TransactionQueued(txId, _target, _value, _data, eta);
        return txId;
    }

    function queueEmergency(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external onlyGuardian returns (bytes32) {
        uint256 eta = block.timestamp + EMERGENCY_DELAY;
        bytes32 txId = _getTxId(_target, _value, _data, eta, true);
        require(transactions[txId].eta == 0, "already queued");

        transactions[txId] = Transaction({
            target: _target,
            value: _value,
            data: _data,
            eta: eta,
            executed: false,
            emergency: true,
            approvalCount: 1
        });
        approvals[txId][msg.sender] = true;

        emit EmergencyQueued(txId, _target, _value, _data, eta);
        emit EmergencyApproved(txId, msg.sender, 1);
        return txId;
    }

    function approveEmergency(bytes32 _txId) external onlyGuardian {
        Transaction storage txn = transactions[_txId];
        require(txn.eta != 0, "not queued");
        require(txn.emergency, "not emergency");
        require(!txn.executed, "already executed");
        require(!approvals[_txId][msg.sender], "already approved");

        approvals[_txId][msg.sender] = true;
        txn.approvalCount++;

        emit EmergencyApproved(_txId, msg.sender, txn.approvalCount);
    }

    function executeTransaction(bytes32 _txId) external payable {
        Transaction storage txn = transactions[_txId];
        require(txn.eta != 0, "not queued");
        require(!txn.executed, "already executed");
        require(block.timestamp >= txn.eta, "not ready");
        require(block.timestamp <= txn.eta + GRACE_PERIOD, "expired");

        if (txn.emergency) {
            uint256 required = _supermajorityThreshold();
            require(txn.approvalCount >= required, "insufficient approvals");
        } else {
            require(msg.sender == admin, "not admin");
        }

        txn.executed = true;

        (bool success, bytes memory result) = txn.target.call{value: txn.value}(txn.data);
        require(success, string(result));

        emit TransactionExecuted(_txId);
    }

    function cancelTransaction(bytes32 _txId) external onlyAdmin {
        Transaction storage txn = transactions[_txId];
        require(txn.eta != 0, "not queued");
        require(!txn.executed, "already executed");

        delete transactions[_txId];
        emit TransactionCancelled(_txId);
    }

    function addGuardian(address _guardian) external onlyThis {
        require(_guardian != address(0), "zero address");
        require(!isGuardian[_guardian], "already guardian");
        isGuardian[_guardian] = true;
        guardians.push(_guardian);
        emit GuardianAdded(_guardian);
    }

    function removeGuardian(address _guardian) external onlyThis {
        require(isGuardian[_guardian], "not guardian");
        require(guardians.length - 1 >= 3, "min 3 guardians");

        isGuardian[_guardian] = false;
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == _guardian) {
                guardians[i] = guardians[guardians.length - 1];
                guardians.pop();
                break;
            }
        }
        emit GuardianRemoved(_guardian);
    }

    function transferAdmin(address _newAdmin) external onlyThis {
        require(_newAdmin != address(0), "zero address");
        admin = _newAdmin;
        emit AdminTransferred(_newAdmin);
    }

    function getGuardianCount() external view returns (uint256) {
        return guardians.length;
    }

    function _supermajorityThreshold() internal view returns (uint256) {
        return (guardians.length * SUPERMAJORITY_NUMERATOR + SUPERMAJORITY_DENOMINATOR - 1) / SUPERMAJORITY_DENOMINATOR;
    }

    function _getTxId(
        address _target,
        uint256 _value,
        bytes memory _data,
        uint256 _eta,
        bool _emergency
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(_target, _value, _data, _eta, _emergency));
    }

    receive() external payable {}
}