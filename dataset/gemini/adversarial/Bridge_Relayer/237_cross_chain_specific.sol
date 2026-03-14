// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleBridgeRelayer {

    address public owner;
    address public destinationChainContract; // Address of the contract on the destination chain to call

    event MessageSent(address indexed sender, bytes32 indexed messageId, bytes message);

    constructor(address _destinationChainContract) {
        owner = msg.sender;
        destinationChainContract = _destinationChainContract;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    /**
     * @notice Relays a message from the source chain to the destination chain.
     * @dev This contract trusts the sender to provide accurate and verified data from the source chain.
     *      No complex cross-chain verification logic is performed here.
     * @param _message The message payload to be sent.
     * @return messageId A unique identifier for the relayed message.
     */
    function relayMessage(bytes calldata _message) external onlyOwner returns (bytes32 messageId) {
        // In a real-world scenario, you would have a mechanism to verify the message
        // originated from the source chain and was authorized. This simple example
        // omits that for brevity and focuses on the relaying aspect.

        // Generate a simple message ID (e.g., keccak256 of the message and sender)
        messageId = keccak256(abi.encodePacked(msg.sender, _message, block.timestamp));

        // Emit an event to signal that a message has been relayed.
        // This event can be monitored by a listener on the destination chain.
        emit MessageSent(msg.sender, messageId, _message);

        // In a more advanced scenario, you might interact with a specific
        // interface on the destination chain contract. For this simple example,
        // we assume the destination chain contract has a function that can be
        // called with the message payload, or that the event is sufficient for
        // a listener on the destination to trigger an action.

        // If you intended to call a function on the destination chain contract:
        // (destinationChainContract).processMessage(messageId, _message);
        // This would require the destinationChainContract to be callable and have
        // a matching function signature.

        return messageId;
    }

    /**
     * @notice Allows the owner to update the destination chain contract address.
     * @param _newDestinationChainContract The new address of the contract on the destination chain.
     */
    function updateDestinationChainContract(address _newDestinationChainContract) external onlyOwner {
        destinationChainContract = _newDestinationChainContract;
    }

    /**
     * @notice Allows the owner to transfer ownership of the contract.
     * @param _newOwner The address of the new owner.
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }
}