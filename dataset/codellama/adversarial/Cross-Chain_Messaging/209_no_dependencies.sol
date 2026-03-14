// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    event MessageSent(address indexed sender, string message);

    struct Message {
        address sender;
        string message;
    }

    mapping (address => mapping (address => Message[])) messages;

    function sendMessage(address recipient, string memory message) public {
        messages[msg.sender][recipient].push(Message(msg.sender, message));
        emit MessageSent(msg.sender, message);
    }

    function getMessages(address sender, address recipient) public view returns (Message[] memory) {
        return messages[sender][recipient];
    }
}