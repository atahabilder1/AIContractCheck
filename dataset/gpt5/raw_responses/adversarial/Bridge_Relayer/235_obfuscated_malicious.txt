// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, value);
        (bool success, bytes memory ret) = address(token).call(data);
        require(success && (ret.length == 0 || abi.decode(ret, (bool))), "SafeERC20: transfer failed");
    }
}

contract BridgeRelayer {
    using SafeERC20 for IERC20;

    // Ownership
    address public owner;

    // Pausing
    bool public paused;

    // Relayers
    mapping(address => bool) public isRelayer;

    // Replay protection
    mapping(bytes32 => bool) public processed; // source-chain unique IDs (e.g., tx hash or messageId)

    // Reentrancy guard
    uint256 private _status;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _NOT_ENTERED = 1;

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event RelayerUpdated(address indexed relayer, bool allowed);
    event RelayedETH(bytes32 indexed srcTxHash, address indexed recipient, uint256 amount);
    event RelayedToken(bytes32 indexed srcTxHash, address indexed token, address indexed recipient, uint256 amount);
    event EmergencyWithdrawalETH(address indexed to, uint256 amount);
    event EmergencyWithdrawalToken(address indexed token, address indexed to, uint256 amount);

    // Errors
    error NotOwner();
    error NotRelayer();
    error PausedError();
    error NotPausedError();
    error AlreadyProcessed();
    error ZeroAddress();
    error InsufficientBalance();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRelayer() {
        if (!isRelayer[msg.sender]) revert NotRelayer();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPausedError();
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
        _status = _NOT_ENTERED;
    }

    // Admin functions
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setRelayer(address relayer, bool allowed) external onlyOwner {
        if (relayer == address(0)) revert ZeroAddress();
        isRelayer[relayer] = allowed;
        emit RelayerUpdated(relayer, allowed);
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // Core relay functions (payouts from this contract to recipients)
    function relayETH(
        address payable recipient,
        uint256 amount,
        bytes32 srcTxHash
    ) external onlyRelayer whenNotPaused nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (processed[srcTxHash]) revert AlreadyProcessed();
        if (address(this).balance < amount) revert InsufficientBalance();

        processed[srcTxHash] = true;

        (bool ok, ) = recipient.call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit RelayedETH(srcTxHash, recipient, amount);
    }

    function relayERC20(
        IERC20 token,
        address recipient,
        uint256 amount,
        bytes32 srcTxHash
    ) external onlyRelayer whenNotPaused nonReentrant {
        if (address(token) == address(0) || recipient == address(0)) revert ZeroAddress();
        if (processed[srcTxHash]) revert AlreadyProcessed();
        if (token.balanceOf(address(this)) < amount) revert InsufficientBalance();

        processed[srcTxHash] = true;

        token.safeTransfer(recipient, amount);

        emit RelayedToken(srcTxHash, address(token), recipient, amount);
    }

    // Emergency admin functions
    function emergencyWithdrawETH(address payable to) external onlyOwner whenPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH withdraw failed");
        emit EmergencyWithdrawalETH(to, amount);
    }

    function emergencyWithdrawERC20(IERC20 token, address to) external onlyOwner whenPaused nonReentrant {
        if (address(token) == address(0) || to == address(0)) revert ZeroAddress();
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(to, amount);
        emit EmergencyWithdrawalToken(address(token), to, amount);
    }

    function emergencyWithdrawERC20Batch(IERC20[] calldata tokens, address to) external onlyOwner whenPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = tokens[i];
            if (address(token) == address(0)) continue;
            uint256 amount = token.balanceOf(address(this));
            if (amount > 0) {
                token.safeTransfer(to, amount);
                emit EmergencyWithdrawalToken(address(token), to, amount);
            }
        }
    }

    // Views
    function tokenBalance(IERC20 token) external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // Receive ETH
    receive() external payable {}
}