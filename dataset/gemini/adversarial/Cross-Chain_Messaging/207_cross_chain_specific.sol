// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {

    address public owner;
    mapping(uint256 => mapping(address => bytes)) public messages;
    uint256 public nextMessageId;

    event MessageSent(
        uint256 indexed messageId,
        uint256 indexed sourceChainId,
        address indexed sender,
        bytes payload
    );

    event MessageReceived(
        uint256 indexed messageId,
        uint256 indexed destinationChainId,
        address indexed recipient,
        bytes payload
    );

    constructor() {
        owner = msg.sender;
        nextMessageId = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    /**
     * @notice Sends a message to another chain.
     * @param _destinationChainId The ID of the destination chain.
     * @param _recipient The address on the destination chain to receive the message.
     * @param _payload The data to be sent with the message.
     */
    function sendMessage(
        uint256 _destinationChainId,
        address _recipient,
        bytes calldata _payload
    ) external {
        uint256 currentMessageId = nextMessageId;
        nextMessageId++;

        // Store the message for potential retrieval or re-transmission if needed.
        // In a truly trustless system, this would be managed by a relayer.
        // For this simplified version, we're just storing it.
        messages[currentMessageId][msg.sender] = _payload;

        emit MessageSent(currentMessageId, _destinationChainId, msg.sender, _payload);
    }

    /**
     * @notice Receives a message from another chain.
     * @dev This function is intended to be called by a relayer or a bridge contract
     *      on the destination chain. It trusts the incoming data directly.
     * @param _messageId The unique identifier of the message from the source chain.
     * @param _sourceChainId The ID of the chain from which the message originated.
     * @param _sender The address on the source chain that sent the message.
     * @param _recipient The address on the destination chain that should receive the message.
     * @param _payload The data of the message.
     */
    function receiveMessage(
        uint256 _messageId,
        uint256 _sourceChainId,
        address _sender,
        address _recipient,
        bytes calldata _payload
    ) external {
        // In a real-world scenario, you would have mechanisms to verify
        // that this message actually originated from _sourceChainId and was
        // legitimately sent. For this simplified example, we are skipping
        // complex verification and trusting the caller to provide valid data.
        // This could involve checking signatures, sequence numbers, or using
        // a cross-chain communication protocol's validation layer.

        // For demonstration purposes, we can optionally check if the message
        // has already been processed or if it matches a known sent message.
        // However, the core of this "trusts source chain data directly" is
        // that the validation of origin and integrity is simplified or external.

        // Example: If you had a way to map message IDs across chains, you might check:
        // require(isMessageFromSourceChain(_sourceChainId, _messageId), "Invalid message origin");

        // In this simplified contract, we directly emit an event indicating receipt.
        // The actual logic to be executed on the destination chain would be triggered
        // by an external entity (e.g., a relayer) that calls this function.
        emit MessageReceived(_messageId, block.chainid, _recipient, _payload);

        // The actual execution of logic based on the payload would typically happen
        // in another contract or by the entity that called `receiveMessage`.
        // This contract primarily acts as a message bus and event emitter.
    }

    // Placeholder for potential future verification logic.
    // In a real system, this would involve complex cross-chain validation.
    /*
    function isMessageFromSourceChain(uint256 _sourceChainId, uint256 _messageId) internal view returns (bool) {
        // Implementation would depend on the cross-chain communication protocol.
        // For example, checking a state root on the destination chain that is
        // anchored from the source chain.
        return true; // For this simplified example, we always return true.
    }
    */
}