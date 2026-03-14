// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GUARDIAN_COUNT = 5;
    uint256 public constant SUPERMAJORITY = 4; // 4 out of 5 guardians

    address[] public guardians;
    mapping(bytes32 => bool) public queuedTransactions;
    mapping(bytes32 => uint256) public transactionTimestamps;
    mapping(bytes32 => uint256) public transactionApprovals;

    event Queued(bytes32 indexed txHash, uint256 eta);
    event Executed(bytes32 indexed txHash);
    event Cancelled(bytes32 indexed txHash);
    event Approved(bytes32 indexed txHash, address indexed guardian);

    modifier onlyGuardian() {
        require(isGuardian(msg.sender), "Not a guardian");
        _;
    }

    constructor(address[] memory _guardians) {
        require(_guardians.length == GUARDIAN_COUNT, "Invalid number of guardians");
        guardians = _guardians;
    }

    function isGuardian(address _address) public view returns (bool) {
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyGuardian {
        require(eta >= block.timestamp + MIN_DELAY, "ETA too soon");
        require(eta <= block.timestamp + MAX_DELAY, "ETA too long");

        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        queuedTransactions[txHash] = true;
        transactionTimestamps[txHash] = eta;

        emit Queued(txHash, eta);
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyGuardian {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Transaction not queued");

        queuedTransactions[txHash] = false;

        emit Cancelled(txHash);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Transaction not queued");
        require(block.timestamp >= transactionTimestamps[txHash], "Transaction not yet ready");
        require(block.timestamp <= transactionTimestamps[txHash] + MAX_DELAY, "Transaction expired");

        queuedTransactions[txHash] = false;

        (bool success, ) = target.call{value: value}(abi.encodePacked(bytes4(keccak256(bytes(signature))), data));
        require(success, "Transaction execution failed");

        emit Executed(txHash);
    }

    function approveTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyGuardian {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Transaction not queued");

        transactionApprovals[txHash]++;
        emit Approved(txHash, msg.sender);

        if (transactionApprovals[txHash] >= SUPERMAJORITY) {
            executeTransaction(target, value, signature, data, eta);
        }
    }

    function getTxHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }
}