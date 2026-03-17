// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    event MessageReceived(address indexed sender, string message);

    function sendMessage(address _receiver, bytes memory _message) public {
        // Implementation for sending a message to another chain
    }

    function receiveMessage(bytes memory _message) external {
        emit MessageReceived(msg.sender, string(_message));
    }
}