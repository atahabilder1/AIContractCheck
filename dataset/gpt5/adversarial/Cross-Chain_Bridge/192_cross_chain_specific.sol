// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, value);
        (bool ok, bytes memory ret) = address(token).call(data);
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transferFrom.selector, from, to, value);
        (bool ok, bytes memory ret) = address(token).call(data);
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.approve.selector, spender, value);
        (bool ok, bytes memory ret) = address(token).call(data);
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "SafeERC20: approve failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

abstract contract Pausable is Ownable {
    bool public paused;

    event Paused(address indexed account);
    event Unpaused(address indexed account);

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

contract TrustBridge is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Trusted relayer that injects source-chain data.
    address public relayer;

    // Monotonic nonce for emitted lock events on this chain.
    uint64 public nonce;

    // Processed cross-chain message IDs to prevent replays.
    mapping(bytes32 => bool) public processed;

    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);

    // Emitted on the source chain when tokens are locked.
    event Locked(
        uint64 indexed nonce,
        address indexed token,
        address indexed from,
        bytes to,                 // raw recipient bytes on destination chain
        uint256 amount,
        uint256 toChainId
    );

    // Emitted on the destination chain when tokens are unlocked.
    event Unlocked(
        bytes32 indexed messageId,
        uint64 indexed srcNonce,
        address indexed token,
        address to,               // local recipient
        uint256 amount,
        uint256 fromChainId,
        address fromBridge
    );

    constructor(address _relayer) {
        require(_relayer != address(0), "Bridge: zero relayer");
        relayer = _relayer;
        emit RelayerUpdated(address(0), _relayer);
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Bridge: not relayer");
        _;
    }

    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Bridge: zero relayer");
        emit RelayerUpdated(relayer, _relayer);
        relayer = _relayer;
    }

    // User locks tokens on this chain to bridge to another chain.
    function lock(
        address token,
        uint256 amount,
        uint256 toChainId,
        bytes calldata to
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Bridge: amount=0");
        require(token != address(0), "Bridge: token=0");
        require(toChainId != block.chainid, "Bridge: same chain");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint64 n = ++nonce;
        emit Locked(n, token, msg.sender, to, amount, toChainId);
    }

    // Message schema trusted from source chain (provided by the relayer).
    struct Message {
        uint256 srcChainId;
        address srcBridge;
        address token;    // local token on this chain to release
        address to;       // local recipient on this chain
        uint256 amount;
        uint64 nonce;     // nonce from the source chain bridge's Lock event
    }

    function getMessageId(Message calldata m) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                uint256(0x01),                  // version/domain separator
                m.srcChainId,
                m.srcBridge,
                m.token,
                m.to,
                m.amount,
                m.nonce
            )
        );
    }

    // Unlock tokens on this chain based on trusted message from source chain.
    function unlock(Message calldata m) public onlyRelayer nonReentrant whenNotPaused {
        require(m.amount > 0, "Bridge: amount=0");
        require(m.token != address(0), "Bridge: token=0");

        bytes32 id = getMessageId(m);
        require(!processed[id], "Bridge: already processed");
        processed[id] = true;

        IERC20(m.token).safeTransfer(m.to, m.amount);

        emit Unlocked(id, m.nonce, m.token, m.to, m.amount, m.srcChainId, m.srcBridge);
    }

    // Batch version to save gas for relayer operations.
    function unlockBatch(Message[] calldata msgs) external onlyRelayer nonReentrant whenNotPaused {
        for (uint256 i = 0; i < msgs.length; i++) {
            unlock(msgs[i]);
        }
    }

    // Owner can withdraw liquidity (use cautiously).
    function withdrawLiquidity(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Bridge: to=0");
        IERC20(token).safeTransfer(to, amount);
    }

    // Emergency switch for a specific message in case of detected issues (owner can reset if needed).
    function markProcessed(bytes32 messageId, bool value) external onlyOwner {
        processed[messageId] = value;
    }
}