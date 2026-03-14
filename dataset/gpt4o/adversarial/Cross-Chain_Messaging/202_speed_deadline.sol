// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICrossChainBridge {
    function sendMessage(address to, uint256 chainId, bytes memory message) external;
    event MessageSent(address indexed from, address indexed to, uint256 chainId, bytes message);
    event MessageReceived(address indexed from, address indexed to, uint256 chainId, bytes message);
}

contract CrossChainMessenger is ICrossChainBridge {
    mapping(bytes32 => bool) public processedMessages;

    function sendMessage(address to, uint256 chainId, bytes memory message) external override {
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, to, chainId, message));
        require(!processedMessages[messageHash], "Message already processed");
        
        processedMessages[messageHash] = true;
        emit MessageSent(msg.sender, to, chainId, message);
    }

    function receiveMessage(address from, address to, uint256 chainId, bytes memory message) external {
        bytes32 messageHash = keccak256(abi.encodePacked(from, to, chainId, message));
        require(!processedMessages[messageHash], "Message already processed");
        
        processedMessages[messageHash] = true;
        emit MessageReceived(from, to, chainId, message);
    }
}