// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CrossChainBatcher {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Represents a single message to be relayed.
    struct Message {
        address sender;         // The original sender on the source chain.
        address recipient;      // The intended recipient contract on the destination chain.
        uint256 chainId;        // The ID of the destination chain.
        bytes data;             // The payload of the message.
        uint256 timestamp;      // Timestamp when the batch was created.
    }

    // Represents a batch of messages.
    struct MessageBatch {
        uint256 batchId;
        address relayer;
        uint256 creationTimestamp;
        Message[] messages;
        bool processed;
    }

    // Mapping from batch ID to MessageBatch struct.
    mapping(uint256 => MessageBatch) public batches;
    // Counter for generating unique batch IDs.
    uint256 public nextBatchId;

    // Set of authorized relayers.
    EnumerableSet.AddressSet private _relayers;

    // Event emitted when a new batch is created.
    event BatchCreated(uint256 indexed batchId, address indexed relayer, uint256 timestamp);
    // Event emitted when a batch is processed and messages are relayed.
    event BatchProcessed(uint256 indexed batchId, address indexed relayer, uint256 timestamp);
    // Event emitted when a relayer is added or removed.
    event RelayerStatusChanged(address indexed relayer, bool indexed isActive);

    constructor() {
        nextBatchId = 1;
    }

    /**
     * @notice Adds a new relayer address to the authorized list.
     * @param _relayer The address of the relayer to add.
     */
    function addRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "CrossChainBatcher: Invalid relayer address");
        require(_relayers.add(_relayer), "CrossChainBatcher: Relayer already authorized");
        emit RelayerStatusChanged(_relayer, true);
    }

    /**
     * @notice Removes a relayer address from the authorized list.
     * @param _relayer The address of the relayer to remove.
     */
    function removeRelayer(address _relayer) external onlyOwner {
        require(_relayers.contains(_relayer), "CrossChainBatcher: Relayer not authorized");
        _relayers.remove(_relayer);
        emit RelayerStatusChanged(_relayer, false);
    }

    /**
     * @notice Checks if an address is an authorized relayer.
     * @param _relayer The address to check.
     * @return True if the address is an authorized relayer, false otherwise.
     */
    function isRelayer(address _relayer) external view returns (bool) {
        return _relayers.contains(_relayer);
    }

    /**
     * @notice Creates a new batch of messages. This function can only be called by an authorized relayer.
     * @param _messages An array of Message structs to be included in the batch.
     */
    function createBatch(Message[] calldata _messages) external {
        require(_relayers.contains(msg.sender), "CrossChainBatcher: Caller is not an authorized relayer");
        require(_messages.length > 0, "CrossChainBatcher: Batch cannot be empty");

        uint256 currentBatchId = nextBatchId;
        Message[] storage batchMessages = batches[currentBatchId].messages;

        for (uint256 i = 0; i < _messages.length; i++) {
            // Basic validation for each message
            require(_messages[i].recipient != address(0), "CrossChainBatcher: Invalid recipient address");
            require(_messages[i].chainId != 0, "CrossChainBatcher: Invalid chain ID");
            // You might want to add more specific sender validation if needed,
            // e.g., if messages must originate from a specific contract.
            batchMessages.push(_messages[i]);
        }

        batches[currentBatchId] = MessageBatch({
            batchId: currentBatchId,
            relayer: msg.sender,
            creationTimestamp: block.timestamp,
            messages: batchMessages,
            processed: false
        });

        nextBatchId++;
        emit BatchCreated(currentBatchId, msg.sender, block.timestamp);
    }

    /**
     * @notice Processes a batch of messages and relays them to their respective destinations.
     * This function can only be called by the relayer who created the batch.
     * @param _batchId The ID of the batch to process.
     */
    function processBatch(uint256 _batchId) external {
        MessageBatch storage batch = batches[_batchId];
        require(batch.batchId != 0, "CrossChainBatcher: Batch not found");
        require(batch.relayer == msg.sender, "CrossChainBatcher: Caller is not the batch creator");
        require(!batch.processed, "CrossChainBatcher: Batch already processed");

        // Mark batch as processed to prevent re-processing.
        batch.processed = true;

        for (uint256 i = 0; i < batch.messages.length; i++) {
            Message storage message = batch.messages[i];

            // In a real-world scenario, this is where you'd interact with a
            // cross-chain communication protocol (e.g., LayerZero, Axelar, etc.)
            // or a specific bridge contract on the destination chain.
            // For demonstration purposes, we'll just log the message.

            // Example: If you had a function `relayMessage(address recipient, bytes data)`
            // on a target chain that you could call, you would do it here.
            // For this example, we'll emit an event indicating the message is being relayed.

            // NOTE: This contract itself does NOT perform the actual cross-chain
            // message sending. It's a batching and management layer. The actual
            // relaying mechanism would be external to this contract, and the
            // `processBatch` function would trigger that external mechanism.

            // For demonstration, we emit an event that a relaying service would listen to.
            emit MessageRelayed(
                _batchId,
                message.sender,
                message.recipient,
                message.chainId,
                message.data,
                message.timestamp
            );
        }

        emit BatchProcessed(_batchId, msg.sender, block.timestamp);
    }

    // Event to indicate that a message is ready to be relayed by an external service.
    event MessageRelayed(
        uint256 indexed batchId,
        address indexed sender,
        address indexed recipient,
        uint256 chainId,
        bytes data,
        uint256 timestamp
    );

    // --- Access Control ---
    // This is a basic Ownable implementation for demonstration.
    // In a production environment, consider a more robust access control system
    // like OpenZeppelin's AccessControl.

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "CrossChainBatcher: Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "CrossChainBatcher: New owner is the zero address");
        owner = newOwner;
    }
}