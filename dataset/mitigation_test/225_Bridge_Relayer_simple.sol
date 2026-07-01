// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BridgeRelayer is ReentrancyGuard, AccessControl, Pausable {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct Message {
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sender;
        address recipient;
        bytes payload;
        uint256 nonce;
        uint256 timestamp;
        bool executed;
    }

    mapping(bytes32 => Message) public messages;
    mapping(bytes32 => bool) public processedMessages;
    mapping(uint256 => uint256) public chainNonces;
    mapping(uint256 => bool) public supportedChains;

    uint256 public constant MAX_PAYLOAD_SIZE = 10000;
    uint256 public messageTimeout = 7 days;

    event MessageStored(
        bytes32 indexed messageHash,
        uint256 indexed sourceChainId,
        uint256 indexed destinationChainId,
        address sender,
        address recipient,
        uint256 nonce
    );

    event MessageForwarded(
        bytes32 indexed messageHash,
        address indexed relayer,
        uint256 indexed destinationChainId
    );

    event ChainSupportUpdated(uint256 indexed chainId, bool supported);
    event MessageTimeoutUpdated(uint256 newTimeout);

    modifier onlyValidChain(uint256 chainId) {
        require(chainId != 0, "Invalid chain ID");
        require(supportedChains[chainId], "Chain not supported");
        _;
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Zero address not allowed");
        _;
    }

    modifier onlyValidPayload(bytes calldata payload) {
        require(payload.length > 0, "Empty payload");
        require(payload.length <= MAX_PAYLOAD_SIZE, "Payload too large");
        _;
    }

    constructor(address admin) {
        require(admin != address(0), "Zero address not allowed");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RELAYER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function storeMessage(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sender,
        address recipient,
        bytes calldata payload
    ) 
        external 
        onlyRole(RELAYER_ROLE)
        onlyValidChain(sourceChainId)
        onlyValidChain(destinationChainId)
        onlyValidAddress(sender)
        onlyValidAddress(recipient)
        onlyValidPayload(payload)
        whenNotPaused
        nonReentrant
    {
        require(sourceChainId != destinationChainId, "Same chain not allowed");
        
        uint256 nonce = chainNonces[sourceChainId]++;
        
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                sourceChainId,
                destinationChainId,
                sender,
                recipient,
                payload,
                nonce
            )
        );
        
        require(messages[messageHash].timestamp == 0, "Message already exists");
        
        messages[messageHash] = Message({
            sourceChainId: sourceChainId,
            destinationChainId: destinationChainId,
            sender: sender,
            recipient: recipient,
            payload: payload,
            nonce: nonce,
            timestamp: block.timestamp,
            executed: false
        });

        emit MessageStored(
            messageHash,
            sourceChainId,
            destinationChainId,
            sender,
            recipient,
            nonce
        );
    }

    function forwardMessage(bytes32 messageHash)
        external
        onlyRole(RELAYER_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(messageHash != bytes32(0), "Invalid message hash");
        
        Message storage message = messages[messageHash];
        require(message.timestamp != 0, "Message does not exist");
        require(!message.executed, "Message already executed");
        require(!processedMessages[messageHash], "Message already processed");
        require(
            block.timestamp <= message.timestamp + messageTimeout,
            "Message expired"
        );

        // Effects
        message.executed = true;
        processedMessages[messageHash] = true;

        emit MessageForwarded(
            messageHash,
            msg.sender,
            message.destinationChainId
        );
    }

    function getMessage(bytes32 messageHash) 
        external 
        view 
        returns (Message memory) 
    {
        require(messageHash != bytes32(0), "Invalid message hash");
        require(messages[messageHash].timestamp != 0, "Message does not exist");
        
        return messages[messageHash];
    }

    function isMessageValid(bytes32 messageHash) 
        external 
        view 
        returns (bool) 
    {
        if (messageHash == bytes32(0)) return false;
        
        Message storage message = messages[messageHash];
        if (message.timestamp == 0) return false;
        if (message.executed) return false;
        if (processedMessages[messageHash]) return false;
        if (block.timestamp > message.timestamp + messageTimeout) return false;
        
        return true;
    }

    function addRelayer(address relayer) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyValidAddress(relayer)
    {
        grantRole(RELAYER_ROLE, relayer);
    }

    function removeRelayer(address relayer) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyValidAddress(relayer)
    {
        revokeRole(RELAYER_ROLE, relayer);
    }

    function setSupportedChain(uint256 chainId, bool supported)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(chainId != 0, "Invalid chain ID");
        require(chainId != block.chainid, "Cannot modify current chain");
        
        supportedChains[chainId] = supported;
        emit ChainSupportUpdated(chainId, supported);
    }

    function setMessageTimeout(uint256 newTimeout)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newTimeout >= 1 hours, "Timeout too short");
        require(newTimeout <= 30 days, "Timeout too long");
        
        messageTimeout = newTimeout;
        emit MessageTimeoutUpdated(newTimeout);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function getChainNonce(uint256 chainId) external view returns (uint256) {
        return chainNonces[chainId];
    }

    function isChainSupported(uint256 chainId) external view returns (bool) {
        return supportedChains[chainId];
    }
}