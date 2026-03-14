// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {

    address public owner;
    mapping(uint256 => bytes) public messages;
    uint256 public messageCounter;

    event MessageSent(uint256 indexed messageId, bytes message);
    event MessageReceived(uint256 indexed messageId, bytes message);

    constructor() {
        owner = msg.sender;
        messageCounter = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function sendMessage(bytes memory _message) public onlyOwner {
        messageCounter++;
        messages[messageCounter] = _message;
        emit MessageSent(messageCounter, _message);
    }

    function receiveMessage(uint256 _messageId, bytes memory _message) public {
        // In a real cross-chain scenario, this function would be called by a trusted
        // relayer or a cross-chain bridge contract on the target chain.
        // The implementation here is a placeholder and assumes a mechanism for
        // verifying the message's authenticity and origin.

        // For demonstration purposes, we'll simply emit an event.
        // A real implementation would involve more complex verification logic,
        // potentially including digital signatures, proofs, or multi-sig checks.
        require(_messageId > 0, "Invalid message ID");
        require(messages[_messageId].length > 0, "Message not found or already processed");

        // In a true cross-chain scenario, you'd likely want to mark messages as processed
        // to prevent replay attacks. This simplified example doesn't implement that.

        emit MessageReceived(_messageId, _message);
    }

    function getMessage(uint256 _messageId) public view returns (bytes memory) {
        require(_messageId > 0 && _messageId <= messageCounter, "Invalid message ID");
        return messages[_messageId];
    }

    function setMessageCounter(uint256 _counter) public onlyOwner {
        messageCounter = _counter;
    }
}