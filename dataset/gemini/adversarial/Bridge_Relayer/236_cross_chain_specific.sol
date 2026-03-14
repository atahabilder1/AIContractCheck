// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeRelayer {
    address public owner;
    mapping(bytes32 => bool) public processedMessages;

    event MessageRelayed(bytes32 indexed messageId, address indexed sender, bytes payload);

    constructor() {
        owner = msg.sender;
    }

    function relayMessage(
        bytes32 messageId,
        address sender,
        bytes calldata payload
    ) external {
        require(msg.sender == owner, "Only owner can relay messages");
        require(!processedMessages[messageId], "Message already processed");

        processedMessages[messageId] = true;
        emit MessageRelayed(messageId, sender, payload);
    }

    function setOwner(address newOwner) external {
        require(msg.sender == owner, "Only owner can change owner");
        owner = newOwner;
    }
}