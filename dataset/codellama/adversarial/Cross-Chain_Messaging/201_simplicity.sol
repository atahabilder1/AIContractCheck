// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    // Store messages in a mapping with the message ID as the key
    mapping(uint256 => string) private messages;

    // Add a new message to the contract
    function addMessage(string memory _message) public {
        // Get the next available message ID
        uint256 messageId = messages.length;
        // Add the message to the mapping
        messages[messageId] = _message;
        // Emit an event with the message ID and message
        emit NewMessage(messageId, _message);
    }

    // Get a message by ID
    function getMessage(uint256 _messageId) public view returns (string memory) {
        return messages[_messageId];
    }

    // Event to be emitted when a new message is added
    event NewMessage(uint256 messageId, string message);
}