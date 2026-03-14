// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    event MessageSent(address indexed sender, uint256 indexed destinationChainId, bytes message);
    event MessageReceived(address indexed receiver, uint256 indexed sourceChainId, bytes message);

    function sendMessage(uint256 destinationChainId, bytes memory message) public {
        emit MessageSent(msg.sender, destinationChainId, message);
    }

    function receiveMessage(uint256 sourceChainId, address receiver, bytes memory message) public {
        emit MessageReceived(receiver, sourceChainId, message);
    }
}