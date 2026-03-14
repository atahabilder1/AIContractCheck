// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    address private _owner;
    mapping(address => uint256) private _messageCount;
    mapping(address => mapping(uint256 => bytes)) private _messages;

    event MessageSent(address indexed from, address indexed to, uint256 indexed messageId);

    constructor() public {
        _owner = msg.sender;
    }

    function sendMessage(address to, bytes memory message) public {
        require(msg.sender == _owner, "Only the owner can send messages");
        uint256 messageId = _messageCount[to]++;
        _messages[to][messageId] = message;
        emit MessageSent(msg.sender, to, messageId);
    }

    function getMessages(address from) public view returns (uint256[] memory) {
        uint256[] memory messageIds = new uint256[](_messageCount[from]);
        for (uint256 i = 0; i < _messageCount[from]; i++) {
            messageIds[i] = _messages[from][i].messageId;
        }
        return messageIds;
    }
}