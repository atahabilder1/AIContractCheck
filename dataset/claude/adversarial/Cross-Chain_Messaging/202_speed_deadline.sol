// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainMessaging {
    struct Message {
        uint256 srcChainId;
        uint256 dstChainId;
        address sender;
        address receiver;
        bytes payload;
        uint256 nonce;
        uint256 timestamp;
        bool executed;
    }

    address public owner;
    mapping(address => bool) public relayers;
    mapping(bytes32 => Message) public messages;
    mapping(bytes32 => bool) public processedMessages;
    uint256 public nonce;
    uint256 public messageFee;

    event MessageSent(
        bytes32 indexed messageId,
        uint256 indexed dstChainId,
        address sender,
        address receiver,
        bytes payload,
        uint256 nonce
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint256 indexed srcChainId,
        address sender,
        address receiver,
        bytes payload
    );

    event MessageExecuted(bytes32 indexed messageId);
    event RelayerUpdated(address indexed relayer, bool status);
    event FeeUpdated(uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(relayers[msg.sender], "Not relayer");
        _;
    }

    constructor(uint256 _messageFee) {
        owner = msg.sender;
        relayers[msg.sender] = true;
        messageFee = _messageFee;
    }

    function sendMessage(
        uint256 _dstChainId,
        address _receiver,
        bytes calldata _payload
    ) external payable returns (bytes32 messageId) {
        require(msg.value >= messageFee, "Insufficient fee");
        require(_receiver != address(0), "Invalid receiver");
        require(_dstChainId != block.chainid, "Same chain");

        uint256 currentNonce = nonce++;

        messageId = keccak256(
            abi.encodePacked(
                block.chainid,
                _dstChainId,
                msg.sender,
                _receiver,
                _payload,
                currentNonce
            )
        );

        messages[messageId] = Message({
            srcChainId: block.chainid,
            dstChainId: _dstChainId,
            sender: msg.sender,
            receiver: _receiver,
            payload: _payload,
            nonce: currentNonce,
            timestamp: block.timestamp,
            executed: false
        });

        emit MessageSent(messageId, _dstChainId, msg.sender, _receiver, _payload, currentNonce);
    }

    function receiveMessage(
        bytes32 _messageId,
        uint256 _srcChainId,
        address _sender,
        address _receiver,
        bytes calldata _payload,
        uint256 _nonce
    ) external onlyRelayer {
        require(!processedMessages[_messageId], "Already processed");

        bytes32 computedId = keccak256(
            abi.encodePacked(
                _srcChainId,
                block.chainid,
                _sender,
                _receiver,
                _payload,
                _nonce
            )
        );
        require(computedId == _messageId, "Invalid message ID");

        processedMessages[_messageId] = true;

        messages[_messageId] = Message({
            srcChainId: _srcChainId,
            dstChainId: block.chainid,
            sender: _sender,
            receiver: _receiver,
            payload: _payload,
            nonce: _nonce,
            timestamp: block.timestamp,
            executed: false
        });

        emit MessageReceived(_messageId, _srcChainId, _sender, _receiver, _payload);
    }

    function executeMessage(bytes32 _messageId) external {
        Message storage message = messages[_messageId];
        require(message.receiver != address(0), "Message not found");
        require(!message.executed, "Already executed");
        require(processedMessages[_messageId], "Not yet received");

        message.executed = true;

        (bool success, ) = message.receiver.call(_payload(_messageId));
        require(success, "Execution failed");

        emit MessageExecuted(_messageId);
    }

    function _payload(bytes32 _messageId) internal view returns (bytes memory) {
        Message storage message = messages[_messageId];
        return abi.encodeWithSignature(
            "onCrossChainMessage(uint256,address,bytes)",
            message.srcChainId,
            message.sender,
            message.payload
        );
    }

    function setRelayer(address _relayer, bool _status) external onlyOwner {
        relayers[_relayer] = _status;
        emit RelayerUpdated(_relayer, _status);
    }

    function setFee(uint256 _fee) external onlyOwner {
        messageFee = _fee;
        emit FeeUpdated(_fee);
    }

    function withdrawFees(address payable _to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees");
        (bool sent, ) = _to.call{value: balance}("");
        require(sent, "Transfer failed");
        emit FeesWithdrawn(_to, balance);
    }
}

interface ICrossChainReceiver {
    function onCrossChainMessage(
        uint256 srcChainId,
        address sender,
        bytes calldata payload
    ) external;
}