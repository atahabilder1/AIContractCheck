// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: op failed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Ownable {
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
}

contract BasicTokenBridge is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Global monotonically increasing nonce for lock operations
    uint256 public nonce;

    // Pausable state
    bool public paused;

    // Whitelist of supported tokens
    mapping(address => bool) public isSupportedToken;

    // Track total locked per token for accounting/monitoring
    mapping(address => uint256) public totalLocked;

    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event TokenSupportUpdated(address indexed token, bool supported);

    // Emitted when tokens are locked on this chain to be minted on the destination chain
    event TokenLocked(
        address indexed token,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 fromChainId,
        uint256 toChainId,
        uint256 nonce
    );

    // Optional: Emitted when tokens are released back on this chain by the bridge admin (reverse direction)
    event TokenReleased(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 fromChainId,
        uint256 toChainId,
        bytes32 indexed releaseId
    );

    modifier whenNotPaused() {
        require(!paused, "Bridge: paused");
        _;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setTokenSupport(address token, bool supported) external onlyOwner {
        require(token != address(0), "Bridge: zero token");
        isSupportedToken[token] = supported;
        emit TokenSupportUpdated(token, supported);
    }

    // Lock ERC20 tokens on this chain and emit an event for off-chain relayers to mint on the destination chain
    function lock(
        address token,
        address recipient,
        uint256 amount,
        uint256 toChainId
    ) external nonReentrant whenNotPaused returns (uint256 lockNonce) {
        require(isSupportedToken[token], "Bridge: unsupported token");
        require(recipient != address(0), "Bridge: zero recipient");
        require(amount > 0, "Bridge: zero amount");
        require(toChainId != 0, "Bridge: invalid dest chain");

        // Handle fee-on-transfer tokens: compute actual received amount
        uint256 pre = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 post = IERC20(token).balanceOf(address(this));
        uint256 received = post - pre;
        require(received > 0, "Bridge: nothing received");

        unchecked {
            totalLocked[token] += received;
        }

        lockNonce = ++nonce;

        emit TokenLocked(
            token,
            msg.sender,
            recipient,
            received,
            block.chainid,
            toChainId,
            lockNonce
        );
    }

    // Optional admin-controlled release for reverse bridging (after off-chain verification).
    // releaseId should be unique across releases (e.g., hash of source event).
    function adminRelease(
        address token,
        address recipient,
        uint256 amount,
        uint256 fromChainId,
        bytes32 releaseId
    ) external onlyOwner nonReentrant whenNotPaused {
        require(isSupportedToken[token], "Bridge: unsupported token");
        require(recipient != address(0), "Bridge: zero recipient");
        require(amount > 0, "Bridge: zero amount");
        require(fromChainId != 0, "Bridge: invalid source chain");

        // Decrement accounting (best-effort; won't underflow due to solidity 0.8 checks)
        if (totalLocked[token] >= amount) {
            unchecked {
                totalLocked[token] -= amount;
            }
        } else {
            totalLocked[token] = 0;
        }

        IERC20(token).safeTransfer(recipient, amount);

        emit TokenReleased(
            token,
            recipient,
            amount,
            fromChainId,
            block.chainid,
            releaseId
        );
    }

    // Owner can rescue stray tokens (use with care)
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Bridge: zero to");
        IERC20(token).safeTransfer(to, amount);
    }
}