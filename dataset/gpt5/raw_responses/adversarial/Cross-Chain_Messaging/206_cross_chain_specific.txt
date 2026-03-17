// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainMessenger {
    // Minimal custom errors
    error InvalidDestination();
    error AlreadyProcessed();

    // Struct used for batch receive
    struct Message {
        uint64 srcChainId;
        bytes32 srcAddress;
        bytes32 dstAddress;
        uint64 nonce;
        bytes payload;
    }

    // Immutable local chain id to save gas
    uint64 public immutable localChainId;

    // Outbound nonce per (dstChainId, dstAddress)
    mapping(uint64 => mapping(bytes32 => uint64)) public outboundNonce;

    // Processed inbound messages by unique id
    mapping(bytes32 => bool) public processed;

    // Emitted on send; relayers index these to route messages
    event MessageSent(
        uint64 indexed srcChainId,
        bytes32 indexed srcAddress,
        uint64 indexed dstChainId,
        bytes32 dstAddress,
        uint64 nonce,
        bytes payload
    );

    // Emitted on receive; useful for app-level listeners
    event MessageReceived(
        uint64 indexed srcChainId,
        bytes32 indexed srcAddress,
        uint64 indexed dstChainId,
        bytes32 dstAddress,
        uint64 nonce,
        bytes payload
    );

    constructor() {
        localChainId = uint64(block.chainid);
    }

    // Send a message to a destination chain/address. Minimal validation and no fee distribution.
    function sendMessage(uint64 dstChainId, bytes32 dstAddress, bytes calldata payload)
        external
        payable
        returns (uint64 nonce)
    {
        nonce = ++outboundNonce[dstChainId][dstAddress];
        emit MessageSent(localChainId, _addressToBytes32(msg.sender), dstChainId, dstAddress, nonce, payload);
    }

    // Receive a single message. Minimal validation with replay protection and destination check.
    function receiveMessage(
        uint64 srcChainId,
        bytes32 srcAddress,
        bytes32 dstAddress,
        uint64 nonce,
        bytes calldata payload
    ) external {
        if (dstAddress != _addressToBytes32(address(this))) revert InvalidDestination();

        bytes32 id = _computeId(srcChainId, srcAddress, dstAddress, nonce, payload);
        if (processed[id]) revert AlreadyProcessed();
        processed[id] = true;

        emit MessageReceived(srcChainId, srcAddress, localChainId, dstAddress, nonce, payload);
        _onMessage(srcChainId, srcAddress, nonce, payload);
    }

    // Receive a batch of messages. Skips already-processed messages for throughput.
    function receiveBatch(Message[] calldata batch) external {
        bytes32 selfAddr = _addressToBytes32(address(this));
        uint64 local = localChainId;

        for (uint256 i = 0; i < batch.length; ) {
            Message calldata m = batch[i];

            if (m.dstAddress == selfAddr) {
                bytes32 id = _computeId(m.srcChainId, m.srcAddress, m.dstAddress, m.nonce, m.payload);
                if (!processed[id]) {
                    processed[id] = true;
                    emit MessageReceived(m.srcChainId, m.srcAddress, local, m.dstAddress, m.nonce, m.payload);
                    _onMessage(m.srcChainId, m.srcAddress, m.nonce, m.payload);
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    // Compute a unique message id for external verification
    function computeId(
        uint64 srcChainId,
        bytes32 srcAddress,
        bytes32 dstAddress,
        uint64 nonce,
        bytes calldata payload
    ) external pure returns (bytes32) {
        return _computeId(srcChainId, srcAddress, dstAddress, nonce, payload);
    }

    // Hook for app-specific logic; override in inheriting contracts
    function _onMessage(
        uint64 /*srcChainId*/,
        bytes32 /*srcAddress*/,
        uint64 /*nonce*/,
        bytes calldata /*payload*/
    ) internal virtual {}

    // Internal helpers
    function _addressToBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function _computeId(
        uint64 srcChainId,
        bytes32 srcAddress,
        bytes32 dstAddress,
        uint64 nonce,
        bytes calldata payload
    ) internal pure returns (bytes32) {
        // Include payload hash to uniquely identify messages with same params but different payloads
        return keccak256(abi.encodePacked(srcChainId, srcAddress, dstAddress, nonce, keccak256(payload)));
    }
}