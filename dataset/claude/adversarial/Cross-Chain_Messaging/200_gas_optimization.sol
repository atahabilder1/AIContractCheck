// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainMessaging {
    struct Message {
        uint256 srcChain;
        uint256 dstChain;
        address sender;
        address receiver;
        bytes payload;
        uint256 nonce;
        uint256 timestamp;
    }

    address public immutable owner;
    uint256 public immutable chainId;
    uint256 public nonce;

    mapping(address => bool) public relayers;
    mapping(bytes32 => bool) public processedMessages;
    mapping(bytes32 => bool) public sentMessages;

    event MessageSent(
        bytes32 indexed messageId,
        uint256 indexed dstChain,
        address indexed sender,
        address receiver,
        uint256 nonce,
        bytes payload
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint256 indexed srcChain,
        address indexed sender,
        address receiver,
        bytes payload
    );

    event RelayerUpdated(address indexed relayer, bool status);

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyRelayer() {
        require(relayers[msg.sender], "!relayer");
        _;
    }

    constructor() {
        owner = msg.sender;
        chainId = block.chainid;
        relayers[msg.sender] = true;
    }

    function sendMessage(
        uint256 _dstChain,
        address _receiver,
        bytes calldata _payload
    ) external returns (bytes32 messageId) {
        uint256 currentNonce = nonce++;
        messageId = keccak256(
            abi.encodePacked(chainId, _dstChain, msg.sender, _receiver, currentNonce, _payload)
        );
        sentMessages[messageId] = true;

        emit MessageSent(messageId, _dstChain, msg.sender, _receiver, currentNonce, _payload);
    }

    function receiveMessage(
        uint256 _srcChain,
        address _sender,
        address _receiver,
        uint256 _nonce,
        bytes calldata _payload
    ) external onlyRelayer returns (bytes32 messageId) {
        messageId = keccak256(
            abi.encodePacked(_srcChain, chainId, _sender, _receiver, _nonce, _payload)
        );
        require(!processedMessages[messageId], "already processed");
        processedMessages[messageId] = true;

        (bool success, ) = _receiver.call(
            abi.encodeWithSignature(
                "onCrossChainMessage(uint256,address,bytes)",
                _srcChain,
                _sender,
                _payload
            )
        );
        require(success, "delivery failed");

        emit MessageReceived(messageId, _srcChain, _sender, _receiver, _payload);
    }

    function receiveMessageBatch(
        uint256[] calldata _srcChains,
        address[] calldata _senders,
        address[] calldata _receivers,
        uint256[] calldata _nonces,
        bytes[] calldata _payloads
    ) external onlyRelayer {
        uint256 len = _srcChains.length;
        for (uint256 i; i < len; ) {
            bytes32 messageId = keccak256(
                abi.encodePacked(_srcChains[i], chainId, _senders[i], _receivers[i], _nonces[i], _payloads[i])
            );
            if (processedMessages[messageId]) {
                unchecked { ++i; }
                continue;
            }
            processedMessages[messageId] = true;

            (bool success, ) = _receivers[i].call(
                abi.encodeWithSignature(
                    "onCrossChainMessage(uint256,address,bytes)",
                    _srcChains[i],
                    _senders[i],
                    _payloads[i]
                )
            );
            if (success) {
                emit MessageReceived(messageId, _srcChains[i], _senders[i], _receivers[i], _payloads[i]);
            }
            unchecked { ++i; }
        }
    }

    function setRelayer(address _relayer, bool _status) external onlyOwner {
        relayers[_relayer] = _status;
        emit RelayerUpdated(_relayer, _status);
    }

    function computeMessageId(
        uint256 _srcChain,
        uint256 _dstChain,
        address _sender,
        address _receiver,
        uint256 _nonce,
        bytes calldata _payload
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_srcChain, _dstChain, _sender, _receiver, _nonce, _payload));
    }
}