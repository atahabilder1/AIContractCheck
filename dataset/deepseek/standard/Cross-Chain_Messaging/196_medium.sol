// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

contract CrossChainMessenger is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _messageIds;

    struct Message {
        uint256 id;
        address sender;
        address recipient;
        bytes32 sourceChain;
        bytes32 destinationChain;
        bytes data;
    }

    mapping(uint256 => Message) private messages;
    mapping(uint256 => bool) private processedMessages;

    event MessageSent(uint256 indexed id, address indexed sender, address indexed recipient, bytes32 sourceChain, bytes32 destinationChain, bytes data);
    event MessageProcessed(uint256 indexed id, address indexed sender, address indexed recipient, bytes32 sourceChain, bytes32 destinationChain, bytes data);

    function sendMessage(address recipient, bytes32 sourceChain, bytes32 destinationChain, bytes memory data) public payable {
        require(msg.value > 0, "Insufficient gas limit");
        uint256 id = _messageIds.current();
        _messageIds.increment();
        messages[id] = Message(id, msg.sender, recipient, sourceChain, destinationChain, data);
        emit MessageSent(id, msg.sender, recipient, sourceChain, destinationChain, data);
    }

    function processMessage(uint256 id) public {
        require(!processedMessages[id], "Message already processed");
        Message storage message = messages[id];
        require(message.sender != address(0), "Invalid message");
        require(keccak256(abi.encodePacked(message.sourceChain)) == keccak256(abi.encodePacked(msg.sender)), "Invalid source chain");
        processedMessages[id] = true;
        emit MessageProcessed(id, message.sender, message.recipient, message.sourceChain, message.destinationChain, message.data);
        // Execute the message on the destination chain
    }

    function getMessage(uint256 id) public view returns (uint256, address, address, bytes32, bytes32, bytes memory) {
        require(processedMessages[id], "Message not processed");
        Message memory message = messages[id];
        return (message.id, message.sender, message.recipient, message.sourceChain, message.destinationChain, message.data);
    }
}