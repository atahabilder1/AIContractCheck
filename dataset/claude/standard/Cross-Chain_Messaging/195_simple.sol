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
    mapping(address => bool) public authorizedRelayers;
    mapping(bytes32 => Message) public messages;
    mapping(uint256 => bool) public supportedChains;
    uint256 public messageNonce;

    event MessageSent(
        bytes32 indexed messageId,
        uint256 indexed destinationChainId,
        address indexed sender,
        bytes payload,
        uint256 nonce
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint256 indexed sourceChainId,
        address indexed sender,
        bytes payload
    );

    event RelayerUpdated(address indexed relayer, bool authorized);
    event ChainUpdated(uint256 indexed chainId, bool supported);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(authorizedRelayers[msg.sender], "Not authorized relayer");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setRelayer(address _relayer, bool _authorized) external onlyOwner {
        authorizedRelayers[_relayer] = _authorized;
        emit RelayerUpdated(_relayer, _authorized);
    }

    function setSupportedChain(uint256 _chainId, bool _supported) external onlyOwner {
        supportedChains[_chainId] = _supported;
        emit ChainUpdated(_chainId, _supported);
    }

    function sendMessage(uint256 _destinationChainId, bytes calldata _payload) external returns (bytes32) {
        require(supportedChains[_destinationChainId], "Chain not supported");
        require(_payload.length > 0, "Empty payload");

        uint256 nonce = messageNonce++;
        bytes32 messageId = keccak256(
            abi.encodePacked(block.chainid, _destinationChainId, msg.sender, nonce, _payload)
        );

        messages[messageId] = Message({
            sourceChainId: block.chainid,
            sender: msg.sender,
            payload: _payload,
            timestamp: block.timestamp,
            processed: false
        });

        emit MessageSent(messageId, _destinationChainId, msg.sender, _payload, nonce);
        return messageId;
    }

    function receiveMessage(
        bytes32 _messageId,
        uint256 _sourceChainId,
        address _sender,
        bytes calldata _payload
    ) external onlyRelayer {
        require(supportedChains[_sourceChainId], "Source chain not supported");
        require(!messages[_messageId].processed, "Already processed");

        messages[_messageId] = Message({
            sourceChainId: _sourceChainId,
            sender: _sender,
            payload: _payload,
            timestamp: block.timestamp,
            processed: true
        });

        emit MessageReceived(_messageId, _sourceChainId, _sender, _payload);
    }

    function getMessage(bytes32 _messageId) external view returns (Message memory) {
        return messages[_messageId];
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Zero address");
        owner = _newOwner;
    }
}