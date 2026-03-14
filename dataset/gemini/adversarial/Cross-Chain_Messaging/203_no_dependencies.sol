// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {

    struct Message {
        address sender;
        address recipient;
        uint256 chainId;
        bytes payload;
        uint256 timestamp;
    }

    mapping(uint256 => mapping(uint256 => Message)) public messages;
    uint256 public nextMessageId;

    event MessageSent(
        uint256 indexed messageId,
        address indexed sender,
        address indexed recipient,
        uint256 chainId,
        bytes payload,
        uint256 timestamp
    );

    event MessageReceived(
        uint256 indexed messageId,
        address indexed sender,
        address indexed recipient,
        uint256 chainId,
        bytes payload,
        uint256 timestamp
    );

    // Function to send a message to another chain.
    // The `chainId` parameter specifies the target chain.
    // The `recipient` parameter is the address on the target chain.
    // The `payload` is the arbitrary data to be sent.
    function sendMessage(uint256 _chainId, address _recipient, bytes memory _payload) public {
        uint256 messageId = nextMessageId;
        messages[messageId][block.chainid] = Message({
            sender: msg.sender,
            recipient: _recipient,
            chainId: _chainId,
            payload: _payload,
            timestamp: block.timestamp
        });
        nextMessageId++;

        emit MessageSent(messageId, msg.sender, _recipient, _chainId, _payload, block.timestamp);
    }

    // Function to be called by a relayer or another chain's contract
    // to confirm receipt of a message.
    // `_messageId` is the ID of the message that was sent.
    // `_sourceChainId` is the chain ID from which the message originated.
    // `_sender` is the original sender of the message.
    // `_recipient` is the original recipient of the message.
    // `_payload` is the original payload of the message.
    // `_timestamp` is the original timestamp of the message.
    function confirmMessageReceipt(
        uint256 _messageId,
        uint256 _sourceChainId,
        address _sender,
        address _recipient,
        bytes memory _payload,
        uint256 _timestamp
    ) public {
        // Basic validation: Check if the message exists and hasn't been confirmed on this chain before.
        // In a real-world scenario, you'd want more robust validation, potentially involving
        // signatures from trusted relayer networks or cross-chain verification mechanisms.
        // For this example, we'll assume the caller is authorized to confirm receipt.

        // Check if the message was sent from the specified source chain
        require(messages[_messageId][_sourceChainId].sender != address(0), "Message not found on source chain");

        // Check if the message details match
        require(messages[_messageId][_sourceChainId].recipient == _recipient, "Recipient mismatch");
        require(messages[_messageId][_sourceChainId].payload == _payload, "Payload mismatch");
        require(messages[_messageId][_sourceChainId].timestamp == _timestamp, "Timestamp mismatch");

        // Mark the message as received on this chain.
        // We can store a confirmation or simply use the existence of the message
        // in the mapping for the current chain as confirmation.
        // For simplicity, we'll just emit an event. A more complex contract
        // might update a state variable or store a confirmation mapping.

        emit MessageReceived(_messageId, _sender, _recipient, _sourceChainId, _payload, _timestamp);
    }

    // A function to retrieve message details.
    // This is a read-only function and doesn't modify the state.
    function getMessage(uint256 _messageId, uint256 _chainId) public view returns (
        address sender,
        address recipient,
        uint256 chainId,
        bytes memory payload,
        uint256 timestamp
    ) {
        Message storage msgData = messages[_messageId][_chainId];
        return (
            msgData.sender,
            msgData.recipient,
            msgData.chainId,
            msgData.payload,
            msgData.timestamp
        );
    }
}