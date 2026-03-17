// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeRelayer {
    // ========== Events ==========
    event RelayerSet(address indexed relayer, bool allowed);
    event TrustedSenderSet(uint256 indexed srcChainId, address indexed sender, bool trusted);
    event EnforceTrustedSet(bool enforce);
    event MessageRelayed(
        bytes32 indexed messageId,
        uint256 indexed srcChainId,
        address indexed srcSender,
        address target,
        uint256 value,
        bool success,
        bytes returnData
    );
    event MessageStatusReset(bytes32 indexed messageId);
    event OwnerTransferred(address indexed previousOwner, address indexed newOwner);
    event Withdrawn(address indexed to, uint256 amount);

    // ========== Ownership ==========
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnerTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        emit OwnerTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ========== Relayer and Trust Controls ==========
    mapping(address => bool) public isRelayer;
    mapping(uint256 => mapping(address => bool)) public trustedSender; // srcChainId => srcSender => trusted
    bool public enforceTrusted; // if true, only messages from trusted senders (per srcChainId) are accepted

    function setRelayer(address relayer, bool allowed) external onlyOwner {
        isRelayer[relayer] = allowed;
        emit RelayerSet(relayer, allowed);
    }

    function setTrustedSender(uint256 srcChainId, address sender, bool trusted) external onlyOwner {
        trustedSender[srcChainId][sender] = trusted;
        emit TrustedSenderSet(srcChainId, sender, trusted);
    }

    function setEnforceTrusted(bool enforce) external onlyOwner {
        enforceTrusted = enforce;
        emit EnforceTrustedSet(enforce);
    }

    modifier onlyRelayer() {
        require(isRelayer[msg.sender], "Not relayer");
        _;
    }

    // ========== Reentrancy Guard ==========
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ========== Message Status ==========
    // 0 = not processed, 1 = success, 3 = failed
    mapping(bytes32 => uint8) public messageStatus;

    // ========== Core Relay ==========
    // Computes a deterministic ID for the message based on inputs
    function computeMessageId(
        uint256 srcChainId,
        address srcSender,
        address target,
        uint256 value,
        bytes calldata data,
        uint256 nonce
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("BridgeRelayer-v1"),
                srcChainId,
                srcSender,
                target,
                value,
                keccak256(data),
                nonce
            )
        );
    }

    // Relay a message to a target contract with optional ETH value and gas limit.
    // - srcChainId: source chain id the message originated from
    // - srcSender: source sender address on the source chain
    // - target: destination contract to call
    // - data: calldata to send to target
    // - nonce: unique nonce provided by the source side (per source domain)
    // - value: ETH value to forward to the target (must equal msg.value)
    // - gasLimit: if non-zero, attempts to use this gas for the call
    function relayMessage(
        uint256 srcChainId,
        address srcSender,
        address target,
        bytes calldata data,
        uint256 nonce,
        uint256 value,
        uint256 gasLimit
    ) external payable onlyRelayer nonReentrant returns (bytes32 messageId, bool success, bytes memory ret) {
        require(target != address(0), "Target zero");
        if (enforceTrusted) {
            require(trustedSender[srcChainId][srcSender], "Untrusted sender");
        }
        require(msg.value == value, "Bad msg.value");

        messageId = computeMessageId(srcChainId, srcSender, target, value, data, nonce);
        require(messageStatus[messageId] != 1, "Already succeeded");

        uint256 gasToUse = gasLimit == 0 ? gasleft() : gasLimit;

        // Execute call
        (success, ret) = target.call{value: value, gas: gasToUse}(data);

        // Update status
        messageStatus[messageId] = success ? 1 : 3;

        emit MessageRelayed(
            messageId,
            srcChainId,
            srcSender,
            target,
            value,
            success,
            ret
        );
    }

    // Allows retrying a previously failed or unprocessed message using the same parameters.
    function replayMessage(
        uint256 srcChainId,
        address srcSender,
        address target,
        bytes calldata data,
        uint256 nonce,
        uint256 value,
        uint256 gasLimit
    ) external payable onlyRelayer nonReentrant returns (bytes32 messageId, bool success, bytes memory ret) {
        // This simply proxies to relayMessage; included for semantic clarity.
        (messageId, success, ret) = relayMessage(srcChainId, srcSender, target, data, nonce, value, gasLimit);
    }

    // Owner can reset a message status to allow reprocessing (testnet convenience).
    function resetMessageStatus(bytes32 messageId) external onlyOwner {
        messageStatus[messageId] = 0;
        emit MessageStatusReset(messageId);
    }

    // ========== Admin Utilities ==========
    receive() external payable {}
    fallback() external payable {}

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "Zero to");
        uint256 bal = address(this).balance;
        require(amount <= bal, "Insufficient");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Withdraw fail");
        emit Withdrawn(to, amount);
    }
}