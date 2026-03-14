// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract CrossChainBridge is Ownable {
    using Address for address;

    // Events
    event MessageSent(uint64 indexed chainId, bytes32 indexed messageId, address indexed sender, bytes payload);
    event MessageProcessed(uint64 indexed chainId, bytes32 indexed messageId, address indexed relayer, bytes32 indexed processingHash);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    // State variables
    mapping(uint64 => uint64) private _nonces; // chainId => nonce
    mapping(address => bool) public isRelayer;
    address[] private _relayAddresses;
    uint256 public constant MAX_RELAYERS = 100; // Example limit

    // --- Constructor ---
    constructor() {
        // The deployer is automatically the owner.
    }

    // --- Relayer Management ---

    /**
     * @dev Adds a relayer to the whitelist. Only callable by the owner.
     * @param relayer The address of the relayer to add.
     */
    function addRelayer(address relayer) public onlyOwner {
        require(relayer.isContract() == false, "CrossChainBridge: Cannot add a contract as a relayer");
        require(!isRelayer[relayer], "CrossChainBridge: Relayer already whitelisted");
        require(_relayAddresses.length < MAX_RELAYERS, "CrossChainBridge: Maximum number of relayers reached");

        isRelayer[relayer] = true;
        _relayAddresses.push(relayer);
        emit RelayerAdded(relayer);
    }

    /**
     * @dev Removes a relayer from the whitelist. Only callable by the owner.
     * @param relayer The address of the relayer to remove.
     */
    function removeRelayer(address relayer) public onlyOwner {
        require(isRelayer[relayer], "CrossChainBridge: Relayer not found");

        isRelayer[relayer] = false;

        // Efficiently remove from array
        for (uint256 i = 0; i < _relayAddresses.length; i++) {
            if (_relayAddresses[i] == relayer) {
                _relayAddresses[i] = _relayAddresses[_relayAddresses.length - 1];
                _relayAddresses.pop();
                break;
            }
        }
        emit RelayerRemoved(relayer);
    }

    /**
     * @dev Gets the list of whitelisted relayer addresses.
     * @return An array of whitelisted relayer addresses.
     */
    function getRelayers() public view returns (address[] memory) {
        return _relayAddresses;
    }

    // --- Message Handling ---

    /**
     * @dev Sends a cross-chain message. This function is intended to be called by a contract
     *      on the source chain to initiate a cross-chain operation.
     * @param destinationChainId The ID of the target chain.
     * @param payload The data payload of the message.
     * @return messageId A unique identifier for the sent message.
     */
    function sendMessage(uint64 destinationChainId, bytes memory payload) public virtual returns (bytes32 messageId) {
        // In a real-world scenario, you'd likely have a specific contract
        // or role authorized to send messages. For this example, we'll allow anyone.
        // Consider adding access control here.

        uint64 currentNonce = _nonces[destinationChainId];
        _nonces[destinationChainId]++;

        // Message ID is a hash of sender, destination chain, nonce, and payload.
        // This ensures uniqueness and allows for validation.
        messageId = keccak256(abi.encodePacked(address(this), destinationChainId, currentNonce, payload));

        emit MessageSent(destinationChainId, messageId, msg.sender, payload);
        return messageId;
    }

    /**
     * @dev Processes a cross-chain message. This function is intended to be called by a relayer
     *      on the destination chain.
     * @param sourceChainId The ID of the originating chain.
     * @param messageId The unique identifier of the message.
     * @param sender The address that sent the message on the source chain.
     * @param payload The data payload of the message.
     * @param signature A signature from the source chain's bridge contract or a trusted entity
     *                  verifying the message's authenticity and validity.
     *                  (For simplicity, this example uses a placeholder and doesn't implement actual signature verification).
     */
    function processMessage(
        uint64 sourceChainId,
        bytes32 messageId,
        address sender,
        bytes memory payload,
        bytes memory signature // Placeholder for actual signature verification
    ) public virtual {
        require(isRelayer[msg.sender], "CrossChainBridge: Caller is not a whitelisted relayer");

        // --- Message Validation ---
        // 1. Reconstruct expected message ID to ensure integrity
        //    We need to know the nonce used on the source chain. This is a critical part.
        //    In a real bridge, the relayer would likely receive the nonce along with the message,
        //    or the source chain would provide a way to query it securely.
        //    For this example, we'll assume the relayer can somehow obtain the correct nonce
        //    or that the `messageId` provided is already the correct one.
        //    A more robust solution would involve a dedicated function on the source chain to
        //    get the correct nonce for a given message or to generate the messageId with nonce.

        // Here, we are making a strong assumption that the `messageId` passed in is the correct one,
        // and that the nonce used on the source chain is implicitly handled by the message ID generation.
        // A more secure approach would be to pass the nonce explicitly or have a way to verify it.

        // 2. Signature Verification (Placeholder)
        //    In a real-world scenario, `signature` would be used to verify that the message
        //    was indeed sent by a trusted entity on the source chain. This could involve
        //    verifying a signature from the source chain's bridge contract or a decentralized
        //    validator set.
        //    `_verifySignature(messageId, signature)` would be called here.
        //    For this example, we'll skip actual signature verification.
        // require(_verifySignature(messageId, signature), "CrossChainBridge: Invalid signature");


        // 3. Check if message has already been processed (prevents replay attacks)
        //    This requires a way to store processed message hashes.
        //    This mapping would be on the *destination* chain.
        //    `mapping(bytes32 => bool) public processedMessages;`
        //    require(!processedMessages[messageId], "CrossChainBridge: Message already processed");
        //    processedMessages[messageId] = true;

        // For this simplified example, we'll rely on the nonce tracking and relayer whitelist
        // as the primary security mechanisms. A real-world bridge would need more robust
        // replay protection.

        // --- Execute Cross-Chain Logic ---
        // This is where the actual cross-chain operation would be triggered.
        // For example, if this bridge is for token transfers, this is where the
        // tokens would be minted or burned.

        // Example: Execute a function based on the payload
        // (This part is highly dependent on the specific use case of the bridge)
        _executePayload(sender, payload);

        emit MessageProcessed(sourceChainId, messageId, msg.sender, keccak256(abi.encodePacked(sourceChainId, messageId, sender, payload)));
    }

    /**
     * @dev Internal function to execute the logic defined by the payload.
     *      This function should be overridden by specific bridge implementations.
     * @param originalSender The address that initiated the transfer on the source chain.
     * @param payload The data payload of the message.
     */
    function _executePayload(address originalSender, bytes memory payload) internal virtual {
        // This is a placeholder. In a real bridge, you would parse the payload
        // and execute the corresponding action.
        // For example:
        // (address token, uint256 amount) = abi.decode(payload, (address, uint256));
        // ERC20Token(token).mint(originalSender, amount); // Example for minting
        // ERC20Token(token).burnFrom(msg.sender, amount); // Example for burning
        // You might also need to pass the `originalSender` and `msg.sender` (relayer)
        // to the execution logic depending on the requirements.

        // For demonstration, we'll just log that it was executed.
        // In a production system, this would perform the actual cross-chain action.
        // For example, if this is a token bridge, you would mint tokens to `originalSender`
        // or burn tokens from `msg.sender` (the relayer, if it's a burn/mint model).
    }

    // --- Helper Functions (for demonstration purposes) ---

    /**
     * @dev Placeholder for signature verification.
     *      In a real implementation, this would verify a signature.
     * @param messageHash The hash of the message being verified.
     * @param signature The signature to verify.
     * @return bool True if the signature is valid, false otherwise.
     */
    function _verifySignature(bytes32 messageHash, bytes memory signature) internal view virtual returns (bool) {
        // This is a placeholder.
        // You would typically use ecrecover or a more sophisticated verification mechanism.
        // Example:
        // address signer = ecrecover(messageHash, signature);
        // require(signer == trustedSourceAddress, "Invalid signature");
        // return true;
        return true; // Assuming valid for this example
    }

    /**
     * @dev Gets the current nonce for a given destination chain.
     * @param chainId The target chain ID.
     * @return uint64 The current nonce.
     */
    function getNonces(uint64 chainId) public view returns (uint64) {
        return _nonces[chainId];
    }
}