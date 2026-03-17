// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool s, bytes memory d) = address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));
        require(s && (d.length == 0 || abi.decode(d, (bool))), "SafeERC20: transfer failed");
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Owner=0");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NotOwner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "NewOwner=0");
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

    event Paused(address account);
    event Unpaused(address account);

    constructor(address initialOwner) Ownable(initialOwner) {}

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "NotPaused");
        _;
    }

    function emergencyPause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _rgStatus;

    constructor() {
        _rgStatus = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_rgStatus != _ENTERED, "Reentrancy");
        _rgStatus = _ENTERED;
        _;
        _rgStatus = _NOT_ENTERED;
    }
}

contract CrossChainMessenger is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Trusted remote application addresses per chainId
    mapping(uint256 => address) public trustedRemotes;

    // Relayer authorized to deliver cross-chain messages
    address public relayer;

    // Outbound message nonce
    uint256 public outboundNonce;

    // Track processed inbound messages
    mapping(bytes32 => bool) public processedMessages;

    // Optional application storage for last received payload per chain
    mapping(uint256 => bytes) public lastReceivedPayload;

    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);
    event TrustedRemoteUpdated(uint256 indexed chainId, address indexed remote);
    event MessageSent(uint256 indexed dstChainId, address indexed dstAddress, uint256 indexed nonce, bytes payload, uint256 feePaid, address sender);
    event MessageReceived(uint256 indexed srcChainId, address indexed srcAddress, uint256 indexed nonce, bytes payload, address relayer);
    event FundsSwept(address indexed token, address indexed to, uint256 amount);
    event NativeWithdrawn(address indexed to, uint256 amount);

    constructor(address initialOwner, address initialRelayer) Pausable(initialOwner) {
        require(initialRelayer != address(0), "Relayer=0");
        relayer = initialRelayer;
        emit RelayerUpdated(address(0), initialRelayer);
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "NotRelayer");
        _;
    }

    // Admin configuration
    function setRelayer(address newRelayer) external onlyOwner {
        require(newRelayer != address(0), "Relayer=0");
        emit RelayerUpdated(relayer, newRelayer);
        relayer = newRelayer;
    }

    function setTrustedRemote(uint256 chainId, address remote) external onlyOwner {
        require(chainId != block.chainid, "SameChain");
        require(remote != address(0), "Remote=0");
        trustedRemotes[chainId] = remote;
        emit TrustedRemoteUpdated(chainId, remote);
    }

    function clearTrustedRemote(uint256 chainId) external onlyOwner {
        trustedRemotes[chainId] = address(0);
        emit TrustedRemoteUpdated(chainId, address(0));
    }

    // Sending messages
    function sendMessage(uint256 dstChainId, address dstAddress, bytes calldata payload) external payable whenNotPaused nonReentrant returns (uint256 nonce) {
        require(dstChainId != block.chainid, "InvalidDst");
        require(dstAddress != address(0), "Dst=0");
        nonce = ++outboundNonce;
        emit MessageSent(dstChainId, dstAddress, nonce, payload, msg.value, msg.sender);
        // Any msg.value remains in contract for relayer fees; withdrawable by admin in emergencies
    }

    // Receiving messages (relayer-delivered)
    function receiveMessage(
        uint256 srcChainId,
        address srcAddress,
        uint256 nonce,
        bytes calldata payload
    ) external whenNotPaused nonReentrant onlyRelayer {
        require(srcChainId != block.chainid, "InvalidSrc");
        require(srcAddress != address(0), "Src=0");
        require(trustedRemotes[srcChainId] == srcAddress, "UntrustedRemote");

        bytes32 key = keccak256(abi.encodePacked(srcChainId, srcAddress, nonce, keccak256(payload)));
        require(!processedMessages[key], "AlreadyProcessed");
        processedMessages[key] = true;

        lastReceivedPayload[srcChainId] = payload;

        emit MessageReceived(srcChainId, srcAddress, nonce, payload, msg.sender);

        // Application-specific handling can be implemented by extending this contract
        // e.g., internal hook: _onMessage(srcChainId, srcAddress, nonce, payload);
    }

    // Emergency admin functions
    function emergencyWithdrawNative(address payable to) public onlyOwner nonReentrant {
        require(to != address(0), "To=0");
        uint256 amount = address(this).balance;
        if (amount > 0) {
            (bool ok, ) = to.call{value: amount}("");
            require(ok, "NativeWithdrawFail");
            emit NativeWithdrawn(to, amount);
        }
    }

    function emergencySweepERC20(address token, address to) public onlyOwner nonReentrant {
        require(to != address(0), "To=0");
        require(token != address(0), "Token=0");
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) {
            IERC20(token).safeTransfer(to, bal);
            emit FundsSwept(token, to, bal);
        }
    }

    function emergencyWithdrawAllFunds(address payable to, address[] calldata tokens) external onlyOwner nonReentrant {
        emergencyWithdrawNative(to);
        for (uint256 i = 0; i < tokens.length; i++) {
            emergencySweepERC20(tokens[i], to);
        }
    }

    // Allow receiving native token
    receive() external payable {}
}