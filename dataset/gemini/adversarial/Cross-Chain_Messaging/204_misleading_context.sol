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

    mapping(uint256 => Message[]) public messages;
    uint256 public messageCount;

    event MessageSent(
        uint256 indexed messageId,
        address indexed sender,
        address recipient,
        uint256 chainId,
        bytes payload
    );

    event MessageReceived(
        uint256 indexed messageId,
        address indexed sender,
        address recipient,
        uint256 chainId,
        bytes payload
    );

    // Function to send a message to another chain
    function sendMessage(address _recipient, uint256 _chainId, bytes calldata _payload) external {
        messageCount++;
        messages[_chainId].push(Message({
            sender: msg.sender,
            recipient: _recipient,
            chainId: _chainId,
            payload: _payload,
            timestamp: block.timestamp
        }));

        emit MessageSent(messageCount, msg.sender, _recipient, _chainId, _payload);
    }

    // Function to receive a message (called by a relayer or a bridge contract on the destination chain)
    // In a real-world scenario, this would be more complex, involving proofs and signature verification.
    // For testnet, we assume a trusted entity is calling this.
    function receiveMessage(
        address _sender,
        address _recipient,
        uint256 _chainId,
        bytes calldata _payload,
        uint256 _messageId // Assuming the messageId is known or derivable
    ) external {
        // Basic check to ensure the message is intended for this chain
        // In a real scenario, this would be the current chain's ID.
        // For simplicity, we don't check the current chain ID here.
        // The _chainId parameter would typically be the *source* chain ID.

        // In a real contract, you'd verify the authenticity of the message
        // (e.g., using signatures from a trusted sequencer or a consensus mechanism).
        // For this testnet version, we'll assume the caller is trusted.

        emit MessageReceived(_messageId, _sender, _recipient, _chainId, _payload);

        // In a real application, you would likely trigger some logic here
        // based on the received payload and recipient.
        // For example, calling a function on the recipient contract.
        // (bool success, ) = _recipient.call(_payload);
        // require(success, "Message execution failed");
    }

    // Function to retrieve messages sent to a specific chain (for auditing/verification purposes)
    function getMessagesForChain(uint256 _chainId, uint256 _startIndex, uint256 _count) external view returns (Message[] memory) {
        require(_count <= 100, "Cannot retrieve more than 100 messages at once"); // Limit for gas efficiency
        uint256 end = (_startIndex + _count) > messages[_chainId].length ? messages[_chainId].length : (_startIndex + _count);
        Message[] memory result = new Message[](_count);
        uint256 resultIndex = 0;
        for (uint256 i = _startIndex; i < end; i++) {
            result[resultIndex] = messages[_chainId][i];
            resultIndex++;
        }
        return result;
    }

    // Function to get the total number of messages sent
    function getTotalMessageCount() external view returns (uint256) {
        return messageCount;
    }
}