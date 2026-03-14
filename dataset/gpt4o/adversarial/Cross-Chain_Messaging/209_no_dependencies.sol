// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    address public owner;
    uint256 public messageCount;

    struct Message {
        uint256 id;
        address sender;
        string content;
        string targetChain;
        address targetAddress;
        bool delivered;
    }

    mapping(uint256 => Message) public messages;

    event MessageSent(uint256 indexed id, address indexed sender, string targetChain, address targetAddress, string content);
    event MessageDelivered(uint256 indexed id);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function sendMessage(string memory _content, string memory _targetChain, address _targetAddress) public {
        messageCount++;
        messages[messageCount] = Message({
            id: messageCount,
            sender: msg.sender,
            content: _content,
            targetChain: _targetChain,
            targetAddress: _targetAddress,
            delivered: false
        });
        emit MessageSent(messageCount, msg.sender, _targetChain, _targetAddress, _content);
    }

    function deliverMessage(uint256 _messageId) public onlyOwner {
        require(_messageId > 0 && _messageId <= messageCount, "Invalid message ID");
        Message storage message = messages[_messageId];
        require(!message.delivered, "Message already delivered");
        message.delivered = true;
        emit MessageDelivered(_messageId);
    }

    function getMessage(uint256 _messageId) public view returns (Message memory) {
        require(_messageId > 0 && _messageId <= messageCount, "Invalid message ID");
        return messages[_messageId];
    }
}