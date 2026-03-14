// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    event MessageSent(uint256 messageId, string message);

    mapping(uint256 => string) public messages;

    function sendMessage(string memory message) public {
        uint256 messageId = block.number;
        messages[messageId] = message;
        emit MessageSent(messageId, message);
    }

    function getMessages() public view returns (string[] memory) {
        string[] memory messagesArray = new string[](messages.length);
        for (uint256 i = 0; i < messages.length; i++) {
            messagesArray[i] = messages[i];
        }
        return messagesArray;
    }
}