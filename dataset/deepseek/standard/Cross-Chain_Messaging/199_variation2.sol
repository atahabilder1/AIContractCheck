// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageReceiver {
    function receiveMessage(address sender, string memory message) external;
}

contract MessagingProtocol {
    mapping(address => mapping(address => bool)) public allowedSources;

    function addAllowedSource(address receiver, address source) public {
        allowedSources[receiver][source] = true;
    }

    function removeAllowedSource(address receiver, address source) public {
        allowedSources[receiver][source] = false;
    }

    function sendMessage(address receiver, string memory message) public {
        require(allowedSources[receiver][msg.sender], "Source not allowed to send messages");
        IMessageReceiver(receiver).receiveMessage(msg.sender, message);
    }
}