// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    // Constants
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MIN_DELAY = 1 seconds;
    uint256 public constant MAX_DELAY = 30 days;

    // State
    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;
    mapping(bytes32 => uint256) public timestamps;

    // Events
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
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
        require(msg.sender == admin, "Timelock: caller is not admin");
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == address(this), "Timelock: caller must be Timelock");
        _;
    }

    constructor(address admin_, uint256 delay_) {
        require(admin_ != address(0), "Timelock: admin zero address");
        require(delay_ >= MIN_DELAY && delay_ <= MAX_DELAY, "Timelock: delay out of range");
        admin = admin_;
        delay = delay_;
        emit NewAdmin(admin_);
        emit NewDelay(delay_);
    }

    // Admin management via timelock
    function setPendingAdmin(address pendingAdmin_) external onlyTimelock {
        require(pendingAdmin_ != address(0), "Timelock: pending admin zero address");
        pendingAdmin = pendingAdmin_;
        emit NewPendingAdmin(pendingAdmin_);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: caller not pendingAdmin");
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    // Delay management via timelock
    function setDelay(uint256 delay_) external onlyTimelock {
        require(delay_ >= MIN_DELAY && delay_ <= MAX_DELAY, "Timelock: delay out of range");
        delay = delay_;
        emit NewDelay(delay_);
    }

    // Queue a transaction to be executed after the delay
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(target != address(0), "Timelock: target zero address");
        require(eta >= block.timestamp + delay, "Timelock: eta too soon");

        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(!queuedTransactions[txHash], "Timelock: tx already queued");

        queuedTransactions[txHash] = true;
        timestamps[txHash] = eta;

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
        delete timestamps[txHash];

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    // Execute a queued transaction after the required delay and before grace period expiry
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Timelock: tx not queued");

        uint256 queuedEta = timestamps[txHash];
        require(queuedEta == eta, "Timelock: mismatched eta");
        require(block.timestamp >= eta, "Timelock: tx locked");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: tx stale");

        // Effects
        queuedTransactions[txHash] = false;
        delete timestamps[txHash];

        // Build calldata
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // Interaction
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock: transaction execution reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta, returnData);

        return returnData;
    }

    // Helper to compute a transaction hash
    function getTxHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }

    // Allow contract to receive ETH
    receive() external payable {}

    fallback() external payable {}
}