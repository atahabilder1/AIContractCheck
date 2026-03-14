// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    address public owner;
    uint256 public messageCount;

    struct Message {
        uint256 id;
        address sender;
        address recipient;
        string content;
        uint256 timestamp;
        uint256 targetChainId;
    }

    mapping(uint256 => Message) public messages;

    event MessageSent(
        uint256 id,
        address indexed sender,
        address indexed recipient,
        string content,
        uint256 timestamp,
        uint256 targetChainId
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        messageCount = 0;
    }

    function sendMessage(
        address _recipient,
        string memory _content,
        uint256 _targetChainId
    ) public returns (uint256) {
        require(bytes(_content).length > 0, "Content must not be empty");

        messageCount++;
        messages[messageCount] = Message(
            messageCount,
            msg.sender,
            _recipient,
            _content,
            block.timestamp,
            _targetChainId
        );

        emit MessageSent(
            messageCount,
            msg.sender,
            _recipient,
            _content,
            block.timestamp,
            _targetChainId
        );

        return messageCount;
    }

    function getMessage(uint256 _messageId)
        public
        view
        returns (
            address,
            address,
            string memory,
            uint256,
            uint256
        )
    {
        Message storage message = messages[_messageId];
        return (
            message.sender,
            message.recipient,
            message.content,
            message.timestamp,
            message.targetChainId
        );
    }

    function getAllMessages() public view returns (Message[] memory) {
        Message[] memory allMessages = new Message[](messageCount);
        for (uint256 i = 1; i <= messageCount; i++) {
            allMessages[i - 1] = messages[i];
        }
        return allMessages;
    }
}