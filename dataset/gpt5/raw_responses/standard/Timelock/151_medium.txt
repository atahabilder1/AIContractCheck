// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    // Admin management
    address public admin;
    address public pendingAdmin;

    // Timing parameters
    uint256 public delay;
    uint256 public gracePeriod;

    // Bounds for safety
    uint256 public constant MIN_DELAY = 1 hours;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant MIN_GRACE_PERIOD = 1 days;
    uint256 public constant MAX_GRACE_PERIOD = 180 days;

    // Queue tracking
    mapping(bytes32 => bool) public queuedTransactions;

    // Events
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event NewGracePeriod(uint256 indexed newGracePeriod);

    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta, bytes returnData);

    constructor(address admin_, uint256 delay_, uint256 gracePeriod_) {
        require(admin_ != address(0), "Timelock: admin zero");
        require(delay_ >= MIN_DELAY && delay_ <= MAX_DELAY, "Timelock: delay out of range");
        require(gracePeriod_ >= MIN_GRACE_PERIOD && gracePeriod_ <= MAX_GRACE_PERIOD, "Timelock: grace out of range");

        admin = admin_;
        delay = delay_;
        gracePeriod = gracePeriod_;
    }

    // Accept ETH for value transfers
    receive() external payable {}
    fallback() external payable {}

    // Helper: compute transaction hash
    function getTxHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, keccak256(bytes(signature)), keccak256(data), eta));
    }

    // Queue a single transaction
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Timelock: eta too soon");

        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    // Cancel a single transaction
    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    // Execute a single transaction (anyone can execute after eta)
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable returns (bytes memory) {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Timelock: not queued");
        require(block.timestamp >= eta, "Timelock: eta not reached");
        require(block.timestamp <= eta + gracePeriod, "Timelock: transaction stale");

        // Prevent re-execution before external call
        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, _getRevertMsg(returnData));

        emit ExecuteTransaction(txHash, target, value, signature, data, eta, returnData);
        return returnData;
    }

    // Batch queue
    function queueTransactions(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory datas,
        uint256[] memory etas
    ) external onlyAdmin returns (bytes32[] memory txHashes) {
        uint256 len = targets.length;
        require(
            len == values.length && len == signatures.length && len == datas.length && len == etas.length,
            "Timelock: array length mismatch"
        );
        txHashes = new bytes32[](len);
        for (uint256 i = 0; i < len; i++) {
            require(etas[i] >= block.timestamp + delay, "Timelock: eta too soon");
            bytes32 txHash = getTxHash(targets[i], values[i], signatures[i], datas[i], etas[i]);
            queuedTransactions[txHash] = true;
            txHashes[i] = txHash;
            emit QueueTransaction(txHash, targets[i], values[i], signatures[i], datas[i], etas[i]);
        }
    }

    // Batch cancel
    function cancelTransactions(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory datas,
        uint256[] memory etas
    ) external onlyAdmin {
        uint256 len = targets.length;
        require(
            len == values.length && len == signatures.length && len == datas.length && len == etas.length,
            "Timelock: array length mismatch"
        );
        for (uint256 i = 0; i < len; i++) {
            bytes32 txHash = getTxHash(targets[i], values[i], signatures[i], datas[i], etas[i]);
            queuedTransactions[txHash] = false;
            emit CancelTransaction(txHash, targets[i], values[i], signatures[i], datas[i], etas[i]);
        }
    }

    // Batch execute (reverts the entire batch if any execution fails)
    function executeTransactions(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory datas,
        uint256[] memory etas
    ) external payable returns (bytes[] memory returnDatas) {
        uint256 len = targets.length;
        require(
            len == values.length && len == signatures.length && len == datas.length && len == etas.length,
            "Timelock: array length mismatch"
        );
        returnDatas = new bytes[](len);
        for (uint256 i = 0; i < len; i++) {
            bytes32 txHash = getTxHash(targets[i], values[i], signatures[i], datas[i], etas[i]);
            require(queuedTransactions[txHash], "Timelock: not queued");
            require(block.timestamp >= etas[i], "Timelock: eta not reached");
            require(block.timestamp <= etas[i] + gracePeriod, "Timelock: transaction stale");

            // Prevent re-execution before external call
            queuedTransactions[txHash] = false;

            bytes memory callData;
            if (bytes(signatures[i]).length == 0) {
                callData = datas[i];
            } else {
                callData = abi.encodePacked(bytes4(keccak256(bytes(signatures[i]))), datas[i]);
            }

            (bool success, bytes memory ret) = targets[i].call{value: values[i]}(callData);
            require(success, _getRevertMsg(ret));

            returnDatas[i] = ret;
            emit ExecuteTransaction(txHash, targets[i], values[i], signatures[i], datas[i], etas[i], ret);
        }
    }

    // Admin change (two-step with timelock protection)
    // Must be called by the timelock itself via a queued transaction
    function setPendingAdmin(address newPendingAdmin) external {
        require(msg.sender == address(this), "Timelock: caller must be Timelock");
        pendingAdmin = newPendingAdmin;
        emit NewPendingAdmin(newPendingAdmin);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: not pending admin");
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    // Delay configuration (must be executed via timelock)
    function setDelay(uint256 newDelay) external {
        require(msg.sender == address(this), "Timelock: caller must be Timelock");
        require(newDelay >= MIN_DELAY && newDelay <= MAX_DELAY, "Timelock: delay out of range");
        delay = newDelay;
        emit NewDelay(newDelay);
    }

    // Grace period configuration (must be executed via timelock)
    function setGracePeriod(uint256 newGracePeriod) external {
        require(msg.sender == address(this), "Timelock: caller must be Timelock");
        require(newGracePeriod >= MIN_GRACE_PERIOD && newGracePeriod <= MAX_GRACE_PERIOD, "Timelock: grace out of range");
        gracePeriod = newGracePeriod;
        emit NewGracePeriod(newGracePeriod);
    }

    // Internal helper to bubble up revert reasons
    function _getRevertMsg(bytes memory returnData) internal pure returns (string memory) {
        if (returnData.length < 68) return "Timelock: execution reverted";
        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: only admin");
        _;
    }
}