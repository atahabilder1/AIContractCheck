// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    // Constants
    uint256 public constant MIN_DELAY = 1 hours;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    // State
    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    // Events
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 newDelay);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta, bytes result);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not admin");
        _;
    }

    // Constructor
    constructor(address admin_, uint256 delay_) {
        require(admin_ != address(0), "Timelock: admin is zero address");
        require(delay_ >= MIN_DELAY, "Timelock: delay too short");
        require(delay_ <= MAX_DELAY, "Timelock: delay too long");
        admin = admin_;
        delay = delay_;
        emit NewAdmin(admin_);
        emit NewDelay(delay_);
    }

    // Accept ETH
    receive() external payable {}
    fallback() external payable {}

    // Admin management (must be scheduled/executed through timelock)
    function setPendingAdmin(address pendingAdmin_) external {
        require(msg.sender == address(this), "Timelock: caller must be Timelock");
        pendingAdmin = pendingAdmin_;
        emit NewPendingAdmin(pendingAdmin_);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: caller is not pending admin");
        admin = msg.sender;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    // Delay management (must be scheduled/executed through timelock)
    function setDelay(uint256 delay_) external {
        require(msg.sender == address(this), "Timelock: caller must be Timelock");
        require(delay_ >= MIN_DELAY, "Timelock: delay too short");
        require(delay_ <= MAX_DELAY, "Timelock: delay too long");
        delay = delay_;
        emit NewDelay(delay_);
    }

    // Transaction queueing
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(target != address(0), "Timelock: target is zero address");
        require(eta >= block.timestamp + delay, "Timelock: eta too soon");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(!queuedTransactions[txHash], "Timelock: tx already queued");

        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock: tx not queued");

        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable returns (bytes memory) {
        require(target != address(0), "Timelock: target is zero address");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock: tx not queued");
        require(block.timestamp >= eta, "Timelock: eta not reached");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: tx is stale");

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            bytes4 selector = bytes4(keccak256(bytes(signature)));
            callData = abi.encodePacked(selector, data);
        }

        (bool success, bytes memory result) = target.call{value: value}(callData);
        require(success, "Timelock: transaction reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta, result);
        return result;
    }

    // Helper view to compute tx hash off-chain consistency
    function getTxHash(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }
}