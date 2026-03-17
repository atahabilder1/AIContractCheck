// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    // Constants
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    // State
    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    // Events
    event NewAdmin(address indexed oldAdmin, address indexed newAdmin);
    event NewPendingAdmin(address indexed oldPendingAdmin, address indexed newPendingAdmin);
    event NewDelay(uint256 indexed oldDelay, uint256 indexed newDelay);

    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta,
        bytes returnData
    );

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: Caller is not admin");
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == address(this), "Timelock: Caller must be Timelock");
        _;
    }

    constructor(address admin_, uint256 delay_) {
        require(admin_ != address(0), "Timelock: admin is zero address");
        require(delay_ >= MIN_DELAY, "Timelock: delay too short");
        require(delay_ <= MAX_DELAY, "Timelock: delay too long");
        admin = admin_;
        delay = delay_;
        emit NewAdmin(address(0), admin_);
        emit NewDelay(0, delay_);
    }

    // Accept ETH
    receive() external payable {}

    // View helper for transaction hash
    function getTxHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }

    // Queue a transaction to be executed after delay
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Timelock: eta < delay");
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(!queuedTransactions[txHash], "Timelock: tx already queued");

        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    // Cancel a queued transaction
    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Timelock: tx not queued");

        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    // Execute a queued transaction
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Timelock: tx not queued");
        require(block.timestamp >= eta, "Timelock: too early");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: tx stale");

        // Mark as executed before external call to prevent reentrancy
        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock: tx execution reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta, returnData);
        return returnData;
    }

    // Governance functions (must be executed through the timelock itself)
    function setDelay(uint256 newDelay) external onlyTimelock {
        require(newDelay >= MIN_DELAY, "Timelock: delay too short");
        require(newDelay <= MAX_DELAY, "Timelock: delay too long");
        emit NewDelay(delay, newDelay);
        delay = newDelay;
    }

    function setPendingAdmin(address newPendingAdmin) external onlyTimelock {
        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);
        pendingAdmin = newPendingAdmin;
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: caller is not pending admin");
        emit NewAdmin(admin, pendingAdmin);
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }
}