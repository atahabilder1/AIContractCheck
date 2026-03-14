// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    // Event to be emitted whenever a message is sent
    event MessageSent(address indexed from, string message, string destinationChain, address destinationAddress);

    // Mapping to store messages sent across chains
    mapping(address => string[]) public messages;

    // Function to send a message to another chain
    function sendMessage(string calldata _message, string calldata _destinationChain, address _destinationAddress) external {
        require(bytes(_message).length > 0, "Message cannot be empty");
        require(bytes(_destinationChain).length > 0, "Destination chain cannot be empty");
        require(_destinationAddress != address(0), "Invalid destination address");

        // Store the message for the sender
        messages[msg.sender].push(_message);

        // Emit the MessageSent event
        emit MessageSent(msg.sender, _message, _destinationChain, _destinationAddress);
    }

    // Function to get messages sent by a specific address
    function getMessages(address _sender) external view returns (string[] memory) {
        return messages[_sender];
    }
}