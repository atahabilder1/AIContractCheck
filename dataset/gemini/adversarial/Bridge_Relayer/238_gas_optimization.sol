// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GasOptimizedBridgeRelayer {
    address public owner;
    mapping(uint256 => bool) public processedMessages;
    bytes32 public constant MAGIC_VALUE = keccak256("GAS_OPTIMIZED_BRIDGE_RELAY");

    event MessageRelayed(uint256 indexed messageId, address indexed sender, bytes data);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function relayMessage(uint256 _messageId, address _sender, bytes calldata _data) external onlyOwner {
        // Early exit if message has already been processed
        require(!processedMessages[_messageId], "Message already processed");

        // Basic validation (can be expanded based on specific bridge logic)
        // For extreme gas optimization, this validation is minimal.
        // In a real-world scenario, more robust checks would be needed.

        // Mark message as processed to prevent re-entrancy and duplicate processing
        processedMessages[_messageId] = true;

        // Emit event for off-chain listeners
        emit MessageRelayed(_messageId, _sender, _data);
    }

    // Function to allow owner to change ownership (optional, for recovery/management)
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be the zero address");
        owner = _newOwner;
    }
}