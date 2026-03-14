// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CrossChainMessaging {
    struct Message {
        uint256 sourceChainId;
        uint256 destChainId;
        address sender;
        address recipient;
        bytes payload;
        uint256 timestamp;
        bool processed;
    }

    address public owner;
    address public relayer;
    uint256 public messageCount;
    uint256 public nonce;

    mapping(uint256 => Message) public messages;
    mapping(bytes32 => bool) public processedHashes;
    mapping(uint256 => bool) public supportedChains;

    event MessageSent(
        uint256 indexed messageId,
        uint256 indexed destChainId,
        address indexed sender,
        address recipient,
        bytes payload,
        uint256 nonce
    );

    event MessageReceived(
        bytes32 indexed messageHash,
        uint256 indexed sourceChainId,
        address indexed sender,
        address recipient,
        bytes payload
    );

    event ChainAdded(uint256 chainId);
    event ChainRemoved(uint256 chainId);
    event RelayerUpdated(address newRelayer);

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
        supportedChains[1] = true;       // Ethereum
        supportedChains[11155111] = true; // Sepolia
        supportedChains[80001] = true;    // Mumbai
        supportedChains[421614] = true;   // Arbitrum Sepolia
        supportedChains[84532] = true;    // Base Sepolia
    }

    function sendMessage(
        uint256 _destChainId,
        address _recipient,
        bytes calldata _payload
    ) external returns (uint256 messageId) {
        require(supportedChains[_destChainId], "Chain not supported");
        require(_recipient != address(0), "Invalid recipient");
        require(_payload.length > 0, "Empty payload");

        messageId = messageCount++;
        nonce++;

        messages[messageId] = Message({
            sourceChainId: block.chainid,
            destChainId: _destChainId,
            sender: msg.sender,
            recipient: _recipient,
            payload: _payload,
            timestamp: block.timestamp,
            processed: false
        });

        emit MessageSent(messageId, _destChainId, msg.sender, _recipient, _payload, nonce);
    }

    function receiveMessage(
        uint256 _sourceChainId,
        address _sender,
        address _recipient,
        bytes calldata _payload,
        uint256 _nonce
    ) external onlyRelayer {
        require(supportedChains[_sourceChainId], "Source chain not supported");

        bytes32 messageHash = keccak256(
            abi.encodePacked(_sourceChainId, _sender, _recipient, _payload, _nonce)
        );
        require(!processedHashes[messageHash], "Already processed");

        processedHashes[messageHash] = true;

        // If recipient is a contract, attempt to deliver
        if (_recipient.code.length > 0) {
            (bool success, ) = _recipient.call(
                abi.encodeWithSignature(
                    "onMessageReceived(uint256,address,bytes)",
                    _sourceChainId,
                    _sender,
                    _payload
                )
            );
            require(success, "Delivery failed");
        }

        emit MessageReceived(messageHash, _sourceChainId, _sender, _recipient, _payload);
    }

    function sendTextMessage(uint256 _destChainId, address _recipient, string calldata _text) external returns (uint256) {
        return this.sendMessage(_destChainId, _recipient, abi.encode(_text));
    }

    function addChain(uint256 _chainId) external onlyOwner {
        supportedChains[_chainId] = true;
        emit ChainAdded(_chainId);
    }

    function removeChain(uint256 _chainId) external onlyOwner {
        supportedChains[_chainId] = false;
        emit ChainRemoved(_chainId);
    }

    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid relayer");
        relayer = _relayer;
        emit RelayerUpdated(_relayer);
    }

    function getMessage(uint256 _messageId) external view returns (Message memory) {
        return messages[_messageId];
    }

    function isProcessed(bytes32 _hash) external view returns (bool) {
        return processedHashes[_hash];
    }
}

interface ICrossChainReceiver {
    function onMessageReceived(uint256 sourceChainId, address sender, bytes calldata payload) external;
}

contract SampleReceiver is ICrossChainReceiver {
    event ReceivedCrossChainMessage(uint256 sourceChainId, address sender, string text);

    address public messenger;

    constructor(address _messenger) {
        messenger = _messenger;
    }

    function onMessageReceived(uint256 sourceChainId, address sender, bytes calldata payload) external override {
        require(msg.sender == messenger, "Only messenger");
        string memory text = abi.decode(payload, (string));
        emit ReceivedCrossChainMessage(sourceChainId, sender, text);
    }
}