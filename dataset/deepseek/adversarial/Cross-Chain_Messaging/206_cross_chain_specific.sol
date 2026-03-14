// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CrossChainMessaging is Ownable {
    struct Message {
        uint256 id;
        address sender;
        address recipient;
        string content;
        bool sent;
    }

    mapping(uint256 => Message) public messages;
    uint256 public messageCount;

    event MessageSent(uint256 indexed id, address indexed sender, address indexed recipient, string content);

    function sendMessage(address recipient, string memory content) public {
        messageCount++;
        messages[messageCount] = Message(messageCount, msg.sender, recipient, content, false);
        emit MessageSent(messageCount, msg.sender, recipient, content);
    }

    function markMessageSent(uint256 id) public onlyOwner {
        require(messages[id].sent == false, "Message already marked as sent");
        messages[id].sent = true;
    }
}