// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    struct Message {
        uint timestamp;
        address sender;
        string message;
    }

    mapping(uint => Message) public messages;
    uint public messageCount;

    function sendMessage(string calldata _message) external {
        messages[messageCount++] = Message({
            timestamp: block.timestamp,
            sender: msg.sender,
            message: _message
        });
    }

    function getMessages() external view returns (Message[] memory) {
        Message[] memory _messages = new Message[](messageCount);
        for (uint i = 0; i < messageCount; i++) {
            _messages[i] = messages[i];
        }
        return _messages;
    }

    function getMessage(uint _index) external view returns (Message memory) {
        return messages[_index];
    }

    function getMessageCount() external view returns (uint) {
        return messageCount;
    }
}