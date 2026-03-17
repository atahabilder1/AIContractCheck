// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeRelayer {
    // Ownership (minimal)
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    // Reentrancy guard (minimal)
    uint256 private _guard;
    modifier nonReentrant() {
        require(_guard == 1, "REENTRANCY");
        _guard = 2;
        _;
        _guard = 1;
    }

    // Relayer controls
    bool public permissionless = true;
    mapping(address => bool) public relayers;

    // Target allowlist controls
    bool public targetAllowlistEnabled = false;
    mapping(address => bool) public allowedTargets;

    // Fees
    uint256 public feePerCallWei;

    // Replay protection
    bool public replayProtectionEnabled = true;
    mapping(bytes32 => bool) public processed;

    // Events
    event Relayed(
        bytes32 indexed messageId,
        address indexed target,
        uint256 value,
        uint256 srcChainId,
        uint256 nonce,
        address indexed relayer,
        bool success
    );
    event BatchRelayed(address indexed relayer, uint256 total, uint256 successes);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PermissionlessSet(bool enabled);
    event RelayerSet(address indexed relayer, bool allowed);
    event TargetAllowlistEnabled(bool enabled);
    event TargetAllowed(address indexed target, bool allowed);
    event FeePerCallSet(uint256 feePerCallWei);
    event Withdraw(address indexed to, uint256 amount);
    event ReplayProtectionSet(bool enabled);

    // Errors
    error NotRelayer();
    error TargetNotAllowed();
    error DuplicateMessage(bytes32 id);
    error RelayFailed(bytes32 id);

    constructor(
        address _owner,
        bool _permissionless,
        uint256 _feePerCallWei
    ) {
        require(_owner != address(0), "INVALID_OWNER");
        owner = _owner;
        permissionless = _permissionless;
        feePerCallWei = _feePerCallWei;
        _guard = 1;
        emit OwnerChanged(address(0), _owner);
        emit PermissionlessSet(_permissionless);
        emit FeePerCallSet(_feePerCallWei);
    }

    receive() external payable {}

    // Relay a single message
    function relay(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 srcChainId,
        uint256 nonce,
        bool revertOnFail
    ) external payable nonReentrant returns (bool success, bytes memory ret) {
        _checkRelayer(msg.sender);
        _checkTarget(target);

        uint256 required = feePerCallWei + value;
        require(msg.value >= required, "INSUFFICIENT_MSG_VALUE");

        bytes32 id = _computeMessageId(target, value, data, srcChainId, nonce);
        if (replayProtectionEnabled) {
            if (processed[id]) revert DuplicateMessage(id);
            processed[id] = true;
        }

        // Execute
        (success, ret) = target.call{value: value}(data);

        emit Relayed(id, target, value, srcChainId, nonce, msg.sender, success);
        if (revertOnFail && !success) revert RelayFailed(id);

        // Refund any dust
        uint256 refund = msg.value - required;
        if (refund != 0) {
            (bool rf, ) = msg.sender.call{value: refund}("");
            require(rf, "REFUND_FAIL");
        }
    }

    // Relay a batch of messages
    function batchRelay(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        uint256 srcChainId,
        uint256[] calldata nonces,
        bool revertOnFail
    ) external payable nonReentrant returns (uint256 successes) {
        uint256 n = targets.length;
        require(
            n == values.length && n == payloads.length && n == nonces.length,
            "LENGTH_MISMATCH"
        );

        _checkRelayer(msg.sender);

        uint256 totalValue = 0;
        unchecked {
            for (uint256 i = 0; i < n; i++) {
                totalValue += values[i];
            }
        }
        uint256 required = totalValue + (feePerCallWei * n);
        require(msg.value >= required, "INSUFFICIENT_MSG_VALUE");

        for (uint256 i = 0; i < n; i++) {
            address target = targets[i];
            _checkTarget(target);

            bytes32 id = _computeMessageId(target, values[i], payloads[i], srcChainId, nonces[i]);
            if (replayProtectionEnabled) {
                if (processed[id]) {
                    if (revertOnFail) revert DuplicateMessage(id);
                    emit Relayed(id, target, values[i], srcChainId, nonces[i], msg.sender, false);
                    continue;
                }
                processed[id] = true;
            }

            (bool ok, ) = target.call{value: values[i]}(payloads[i]);
            if (ok) successes++;
            else if (revertOnFail) revert RelayFailed(id);

            emit Relayed(id, target, values[i], srcChainId, nonces[i], msg.sender, ok);
        }

        emit BatchRelayed(msg.sender, n, successes);

        // Refund any dust
        uint256 refund = msg.value - required;
        if (refund != 0) {
            (bool rf, ) = msg.sender.call{value: refund}("");
            require(rf, "REFUND_FAIL");
        }
    }

    // View helpers
    function quoteFee(uint256 calls, uint256 totalTransferValue) external view returns (uint256) {
        return totalTransferValue + (feePerCallWei * calls);
    }

    function computeMessageId(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 srcChainId,
        uint256 nonce
    ) external pure returns (bytes32) {
        return _computeMessageId(target, value, data, srcChainId, nonce);
    }

    // Admin
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "INVALID_OWNER");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    function setPermissionless(bool enabled) external onlyOwner {
        permissionless = enabled;
        emit PermissionlessSet(enabled);
    }

    function setRelayer(address account, bool allowed) external onlyOwner {
        relayers[account] = allowed;
        emit RelayerSet(account, allowed);
    }

    function setTargetAllowlistEnabled(bool enabled) external onlyOwner {
        targetAllowlistEnabled = enabled;
        emit TargetAllowlistEnabled(enabled);
    }

    function setTargetAllowed(address target, bool allowed) external onlyOwner {
        allowedTargets[target] = allowed;
        emit TargetAllowed(target, allowed);
    }

    function setFeePerCallWei(uint256 fee) external onlyOwner {
        feePerCallWei = fee;
        emit FeePerCallSet(fee);
    }

    function setReplayProtection(bool enabled) external onlyOwner {
        replayProtectionEnabled = enabled;
        emit ReplayProtectionSet(enabled);
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "INVALID_TO");
        (bool s, ) = to.call{value: amount}("");
        require(s, "WITHDRAW_FAIL");
        emit Withdraw(to, amount);
    }

    // Internal helpers
    function _checkRelayer(address sender) internal view {
        if (!permissionless && !relayers[sender]) revert NotRelayer();
    }

    function _checkTarget(address target) internal view {
        if (targetAllowlistEnabled && !allowedTargets[target]) revert TargetNotAllowed();
    }

    function _computeMessageId(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 srcChainId,
        uint256 nonce
    ) internal pure returns (bytes32) {
        // Minimal yet sufficiently unique across lanes
        return keccak256(abi.encodePacked(srcChainId, nonce, target, value, keccak256(data)));
    }
}