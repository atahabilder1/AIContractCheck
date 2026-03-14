// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainMessaging {
    struct Message {
        uint256 messageId;
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sender;
        address recipient;
        bytes payload;
        uint256 timestamp;
        MessageStatus status;
    }

    enum MessageStatus {
        Pending,
        Relayed,
        Executed,
        Failed
    }

    address public owner;
    uint256 public messageNonce;
    uint256 public requiredConfirmations;
    uint256 public messageFee;

    mapping(uint256 => Message) public messages;
    mapping(uint256 => bool) public supportedChains;
    mapping(address => bool) public relayers;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    mapping(uint256 => uint256) public confirmationCount;
    mapping(bytes32 => bool) public executedMessages;

    event MessageSent(
        uint256 indexed messageId,
        uint256 indexed destinationChainId,
        address indexed sender,
        address recipient,
        bytes payload
    );

    event MessageRelayed(
        uint256 indexed messageId,
        address indexed relayer
    );

    event MessageConfirmed(
        uint256 indexed messageId,
        address indexed relayer,
        uint256 confirmations
    );

    event MessageExecuted(
        uint256 indexed messageId,
        address indexed recipient,
        bool success
    );

    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event ChainAdded(uint256 indexed chainId);
    event ChainRemoved(uint256 indexed chainId);
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

    constructor(uint256 _requiredConfirmations, uint256 _messageFee) {
        require(_requiredConfirmations > 0, "Confirmations must be > 0");
        owner = msg.sender;
        requiredConfirmations = _requiredConfirmations;
        messageFee = _messageFee;
        supportedChains[block.chainid] = true;
    }

    function sendMessage(
        uint256 _destinationChainId,
        address _recipient,
        bytes calldata _payload
    ) external payable returns (uint256) {
        require(supportedChains[_destinationChainId], "Chain not supported");
        require(_recipient != address(0), "Invalid recipient");
        require(_payload.length > 0, "Empty payload");
        require(msg.value >= messageFee, "Insufficient fee");

        uint256 messageId = messageNonce++;

        messages[messageId] = Message({
            messageId: messageId,
            sourceChainId: block.chainid,
            destinationChainId: _destinationChainId,
            sender: msg.sender,
            recipient: _recipient,
            payload: _payload,
            timestamp: block.timestamp,
            status: MessageStatus.Pending
        });

        emit MessageSent(messageId, _destinationChainId, msg.sender, _recipient, _payload);

        return messageId;
    }

    function confirmMessage(uint256 _messageId) external onlyRelayer {
        require(_messageId < messageNonce, "Message does not exist");
        require(!confirmations[_messageId][msg.sender], "Already confirmed");
        require(messages[_messageId].status == MessageStatus.Pending, "Not pending");

        confirmations[_messageId][msg.sender] = true;
        confirmationCount[_messageId]++;

        emit MessageConfirmed(_messageId, msg.sender, confirmationCount[_messageId]);

        if (confirmationCount[_messageId] >= requiredConfirmations) {
            messages[_messageId].status = MessageStatus.Relayed;
            emit MessageRelayed(_messageId, msg.sender);
        }
    }

    function executeMessage(uint256 _messageId) external {
        Message storage message = messages[_messageId];
        require(message.status == MessageStatus.Relayed, "Not relayed");
        require(confirmationCount[_messageId] >= requiredConfirmations, "Not enough confirmations");

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                message.messageId,
                message.sourceChainId,
                message.sender,
                message.recipient,
                message.payload
            )
        );
        require(!executedMessages[messageHash], "Already executed");

        executedMessages[messageHash] = true;

        (bool success, ) = message.recipient.call(
            abi.encodeWithSignature(
                "onCrossChainMessage(uint256,address,bytes)",
                message.sourceChainId,
                message.sender,
                message.payload
            )
        );

        if (success) {
            message.status = MessageStatus.Executed;
        } else {
            message.status = MessageStatus.Failed;
        }

        emit MessageExecuted(_messageId, message.recipient, success);
    }

    function retryFailedMessage(uint256 _messageId) external {
        Message storage message = messages[_messageId];
        require(message.status == MessageStatus.Failed, "Not failed");
        require(
            msg.sender == message.sender || msg.sender == owner,
            "Not authorized"
        );

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                message.messageId,
                message.sourceChainId,
                message.sender,
                message.recipient,
                message.payload
            )
        );
        executedMessages[messageHash] = false;
        message.status = MessageStatus.Relayed;
    }

    function addRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid address");
        require(!relayers[_relayer], "Already relayer");
        relayers[_relayer] = true;
        emit RelayerAdded(_relayer);
    }

    function removeRelayer(address _relayer) external onlyOwner {
        require(relayers[_relayer], "Not relayer");
        relayers[_relayer] = false;
        emit RelayerRemoved(_relayer);
    }

    function addSupportedChain(uint256 _chainId) external onlyOwner {
        require(!supportedChains[_chainId], "Already supported");
        supportedChains[_chainId] = true;
        emit ChainAdded(_chainId);
    }

    function removeSupportedChain(uint256 _chainId) external onlyOwner {
        require(_chainId != block.chainid, "Cannot remove current chain");
        require(supportedChains[_chainId], "Not supported");
        supportedChains[_chainId] = false;
        emit ChainRemoved(_chainId);
    }

    function setRequiredConfirmations(uint256 _confirmations) external onlyOwner {
        require(_confirmations > 0, "Must be > 0");
        requiredConfirmations = _confirmations;
    }

    function setMessageFee(uint256 _fee) external onlyOwner {
        messageFee = _fee;
        emit FeeUpdated(_fee);
    }

    function withdrawFees(address payable _to) external onlyOwner {
        require(_to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        (bool success, ) = _to.call{value: balance}("");
        require(success, "Transfer failed");
        emit FeesWithdrawn(_to, balance);
    }

    function getMessage(uint256 _messageId) external view returns (Message memory) {
        require(_messageId < messageNonce, "Message does not exist");
        return messages[_messageId];
    }

    function getMessageStatus(uint256 _messageId) external view returns (MessageStatus) {
        require(_messageId < messageNonce, "Message does not exist");
        return messages[_messageId].status;
    }

    function isRelayer(address _account) external view returns (bool) {
        return relayers[_account];
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
}

interface ICrossChainReceiver {
    function onCrossChainMessage(
        uint256 sourceChainId,
        address sender,
        bytes calldata payload
    ) external;
}