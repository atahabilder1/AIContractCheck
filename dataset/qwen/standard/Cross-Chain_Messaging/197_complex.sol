// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LayerZeroEndpoint {
    address public owner;
    address public oracle;
    address public relayer;

    uint256 public minDelay;
    uint256 public maxDelay;
    uint256 public maxRetries;

    mapping(uint256 => Message) public messages;
    uint256 public nonce;

    struct Message {
        address sender;
        uint256 destinationChainId;
        bytes payload;
        uint256 nonce;
        uint256 attempts;
        bool delivered;
    }

    event MessageSent(uint256 indexed nonce, address indexed sender, uint256 destinationChainId);
    event MessageDelivered(uint256 indexed nonce, uint256 indexed destinationChainId);
    event MessageFailed(uint256 indexed nonce, uint256 indexed destinationChainId, uint256 attempts);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Not the oracle");
        _;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Not the relayer");
        _;
    }

    constructor(address _oracle, address _relayer, uint256 _minDelay, uint256 _maxDelay, uint256 _maxRetries) {
        owner = msg.sender;
        oracle = _oracle;
        relayer = _relayer;
        minDelay = _minDelay;
        maxDelay = _maxDelay;
        maxRetries = _maxRetries;
        nonce = 0;
    }

    function sendMessage(uint256 _destinationChainId, bytes calldata _payload) external {
        require(_destinationChainId > 0, "Invalid destination chain ID");
        require(_payload.length > 0, "Payload cannot be empty");

        nonce++;
        messages[nonce] = Message({
            sender: msg.sender,
            destinationChainId: _destinationChainId,
            payload: _payload,
            nonce: nonce,
            attempts: 0,
            delivered: false
        });

        emit MessageSent(nonce, msg.sender, _destinationChainId);
    }

    function deliverMessage(uint256 _nonce) external onlyRelayer {
        Message storage msgData = messages[_nonce];
        require(msgData.nonce == _nonce, "Invalid nonce");
        require(!msgData.delivered, "Message already delivered");
        require(msgData.attempts < maxRetries, "Max retries reached");

        msgData.attempts++;
        msgData.delivered = true;

        emit MessageDelivered(_nonce, msgData.destinationChainId);
    }

    function failMessage(uint256 _nonce) external onlyRelayer {
        Message storage msgData = messages[_nonce];
        require(msgData.nonce == _nonce, "Invalid nonce");
        require(!msgData.delivered, "Message already delivered");
        require(msgData.attempts < maxRetries, "Max retries reached");

        msgData.attempts++;

        emit MessageFailed(_nonce, msgData.destinationChainId, msgData.attempts);
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
    }

    function setMinDelay(uint256 _minDelay) external onlyOwner {
        minDelay = _minDelay;
    }

    function setMaxDelay(uint256 _maxDelay) external onlyOwner {
        require(_maxDelay >= minDelay, "Max delay must be greater than or equal to min delay");
        maxDelay = _maxDelay;
    }

    function setMaxRetries(uint256 _maxRetries) external onlyOwner {
        maxRetries = _maxRetries;
    }
}