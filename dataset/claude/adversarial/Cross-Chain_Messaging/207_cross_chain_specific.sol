// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainMessaging {
    struct Message {
        uint256 sourceChainId;
        address sender;
        bytes payload;
        uint256 timestamp;
        bool processed;
    }

    address public owner;
    address public relayer;

    mapping(bytes32 => Message) public messages;
    mapping(uint256 => bool) public supportedChains;
    mapping(bytes32 => bool) public processedNonces;

    uint256 public messageCount;

    event MessageSent(
        bytes32 indexed messageId,
        uint256 destinationChainId,
        address indexed sender,
        bytes payload
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint256 sourceChainId,
        address indexed sender,
        bytes payload
    );

    event MessageProcessed(bytes32 indexed messageId);
    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);
    event ChainSupported(uint256 chainId, bool supported);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Not relayer");
        _;
    }

    constructor(address _relayer) {
        owner = msg.sender;
        relayer = _relayer;
    }

    function setSupportedChain(uint256 chainId, bool supported) external onlyOwner {
        supportedChains[chainId] = supported;
        emit ChainSupported(chainId, supported);
    }

    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid relayer");
        address old = relayer;
        relayer = _relayer;
        emit RelayerUpdated(old, _relayer);
    }

    function sendMessage(
        uint256 destinationChainId,
        bytes calldata payload
    ) external returns (bytes32 messageId) {
        require(supportedChains[destinationChainId], "Chain not supported");
        require(payload.length > 0, "Empty payload");

        messageId = keccak256(
            abi.encodePacked(
                block.chainid,
                destinationChainId,
                msg.sender,
                messageCount,
                block.timestamp
            )
        );

        messages[messageId] = Message({
            sourceChainId: block.chainid,
            sender: msg.sender,
            payload: payload,
            timestamp: block.timestamp,
            processed: false
        });

        messageCount++;

        emit MessageSent(messageId, destinationChainId, msg.sender, payload);
    }

    function receiveMessage(
        bytes32 messageId,
        uint256 sourceChainId,
        address sender,
        bytes calldata payload
    ) external onlyRelayer {
        require(supportedChains[sourceChainId], "Source chain not supported");
        require(!processedNonces[messageId], "Already processed");

        processedNonces[messageId] = true;

        messages[messageId] = Message({
            sourceChainId: sourceChainId,
            sender: sender,
            payload: payload,
            timestamp: block.timestamp,
            processed: true
        });

        emit MessageReceived(messageId, sourceChainId, sender, payload);
    }

    function processMessage(bytes32 messageId, address target) external onlyRelayer {
        Message storage message = messages[messageId];
        require(message.timestamp != 0, "Message not found");
        require(!message.processed, "Already processed");

        message.processed = true;

        (bool success, ) = target.call(message.payload);
        require(success, "Execution failed");

        emit MessageProcessed(messageId);
    }

    function getMessage(bytes32 messageId) external view returns (Message memory) {
        return messages[messageId];
    }

    function isMessageProcessed(bytes32 messageId) external view returns (bool) {
        return processedNonces[messageId];
    }
}