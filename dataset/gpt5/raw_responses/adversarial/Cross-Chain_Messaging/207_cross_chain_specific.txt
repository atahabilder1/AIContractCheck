// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrossChainReceiver {
    function onCrossChainMessage(uint64 srcChainId, address srcSender, bytes calldata data) external;
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
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

contract NaiveCrossChainMessenger is Ownable, ReentrancyGuard {
    // Outbound nonce to uniquely identify locally sent messages
    uint256 public outboundNonce;

    // Trusted relayers allowed to submit messages for any source chain
    mapping(address => bool) public trustedRelayers;

    // Trusted application addresses on remote/source chains
    // If zero, no app is trusted for that chain.
    mapping(uint64 => address) public trustedRemoteApps;

    // Per-source-chain processed message ids to prevent simple replay (based on provided srcTxHash)
    mapping(uint64 => mapping(bytes32 => bool)) public processed;

    event RelayerUpdated(address indexed relayer, bool allowed);
    event TrustedRemoteAppUpdated(uint64 indexed srcChainId, address indexed app);

    event MessageSent(
        uint64 indexed dstChainId,
        address indexed from,
        address indexed to,
        bytes data,
        uint256 nonce
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed srcChainId,
        address indexed from,
        address to,
        bytes data,
        bytes32 srcTxHash
    );

    event MessageExecutionResult(
        bytes32 indexed messageId,
        bool success,
        bytes returnData
    );

    modifier onlyRelayer() {
        require(trustedRelayers[msg.sender], "NaiveXCM: not relayer");
        _;
    }

    receive() external payable {}

    // Admin: set or unset a trusted relayer
    function setRelayer(address relayer, bool allowed) external onlyOwner {
        require(relayer != address(0), "NaiveXCM: zero relayer");
        trustedRelayers[relayer] = allowed;
        emit RelayerUpdated(relayer, allowed);
    }

    // Admin: trust a specific application address on a source chain
    function setTrustedRemoteApp(uint64 srcChainId, address app) external onlyOwner {
        trustedRemoteApps[srcChainId] = app;
        emit TrustedRemoteAppUpdated(srcChainId, app);
    }

    // Naive send: emits an event for off-chain relayers to pick up and deliver
    function sendMessage(uint64 dstChainId, address to, bytes calldata data) external payable returns (uint256 nonce) {
        require(to != address(0), "NaiveXCM: zero to");
        nonce = ++outboundNonce;
        emit MessageSent(dstChainId, msg.sender, to, data, nonce);
        // Any msg.value sent can be used as a tip for the relayer, controlled off-chain
    }

    // Naive receive: trusts the provided source chain data and a whitelisted relayer.
    // srcTxHash is an arbitrary off-chain supplied identifier (e.g., source chain tx hash) for replay protection.
    function receiveMessage(
        uint64 srcChainId,
        address from,
        address to,
        bytes calldata data,
        bytes32 srcTxHash
    ) external onlyRelayer nonReentrant returns (bytes32 messageId, bool success, bytes memory returnData) {
        require(to != address(0), "NaiveXCM: zero to");
        address trustedApp = trustedRemoteApps[srcChainId];
        require(trustedApp != address(0), "NaiveXCM: no trusted app");
        require(from == trustedApp, "NaiveXCM: untrusted source app");
        require(!processed[srcChainId][srcTxHash], "NaiveXCM: duplicate");

        processed[srcChainId][srcTxHash] = true;

        messageId = keccak256(abi.encodePacked(address(this), block.chainid, srcChainId, from, to, data, srcTxHash));
        emit MessageReceived(messageId, srcChainId, from, to, data, srcTxHash);

        // If target is a contract implementing ICrossChainReceiver, it can handle the message.
        // Otherwise, we attempt a raw call.
        if (_isContract(to)) {
            // Try calling ICrossChainReceiver first; if it reverts or selector isn't supported, fall back to raw call.
            (bool ok, ) = to.staticcall(abi.encodeWithSelector(ICrossChainReceiver.onCrossChainMessage.selector, srcChainId, from, data));
            if (ok) {
                // The contract likely supports the interface; now make the state-changing call.
                (success, returnData) =
                    to.call(abi.encodeWithSelector(ICrossChainReceiver.onCrossChainMessage.selector, srcChainId, from, data));
            } else {
                (success, returnData) = to.call(data);
            }
        } else {
            // Non-contract destination; raw call with data will always fail. Emit result regardless.
            (success, returnData) = to.call(data);
        }

        emit MessageExecutionResult(messageId, success, returnData);
    }

    // Utility to compute the same messageId off-chain for a given receive payload
    function computeMessageId(
        uint64 srcChainId,
        address from,
        address to,
        bytes calldata data,
        bytes32 srcTxHash
    ) external view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), block.chainid, srcChainId, from, to, data, srcTxHash));
    }

    function _isContract(address account) private view returns (bool) {
        return account.code.length > 0;
    }
}