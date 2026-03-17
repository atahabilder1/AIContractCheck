// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    // Define a struct to represent a message
    struct Message {
        address sender;
        string content;
        uint256 timestamp;
    }

    // Mapping of message hashes to their contents
    mapping(bytes32 => Message) public messages;

    // Event that is emitted when a new message is received
    event NewMessage(address indexed sender, string content, uint256 indexed timestamp);

    // Function to send a message across chains
    function sendMessage(string memory _content, address _destinationChain) public {
        bytes32 messageHash = keccak256(abi.encodePacked(_content, msg.sender));
        messages[messageHash] = Message(msg.sender, _content, block.timestamp);
        emit NewMessage(msg.sender, _content, block.timestamp);
    }
}