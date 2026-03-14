// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CrossChainMessenger {

    address public owner;
    mapping(uint256 => bytes) public messages;
    uint256 public nextMessageId;

    event MessageSent(uint256 indexed messageId, bytes message);
    event MessageReceived(uint256 indexed messageId, bytes message);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function sendMessage(bytes calldata _message) external {
        uint256 messageId = nextMessageId++;
        messages[messageId] = _message;
        emit MessageSent(messageId, _message);
    }

    function receiveMessage(uint256 _messageId, bytes calldata _message) external {
        // In a real-world scenario, this function would have
        // robust authentication and authorization mechanisms
        // to verify the sender and the integrity of the message
        // from the originating chain.
        // For gas optimization and simplicity in this example,
        // we assume these checks are handled off-chain or by
        // a trusted relay mechanism.

        // We can optionally check if the message was already received,
        // but this adds gas cost. For minimal gas, we omit it.
        // require(messages[_messageId] == bytes(0), "Message already received");

        messages[_messageId] = _message; // Overwrite or store, depending on desired logic
        emit MessageReceived(_messageId, _message);
    }

    function getMessage(uint256 _messageId) external view returns (bytes memory) {
        return messages[_messageId];
    }

    function setOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }
}