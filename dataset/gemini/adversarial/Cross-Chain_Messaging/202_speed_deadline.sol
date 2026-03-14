// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {

    struct Message {
        address sender;
        address receiver;
        bytes data;
        uint256 chainId;
    }

    mapping(uint256 => Message[]) public messagesByChain;
    uint256 public messageCount;

    event MessageSent(
        uint256 indexed messageId,
        address indexed sender,
        address indexed receiver,
        uint256 chainId,
        bytes data
    );

    event MessageReceived(
        uint256 indexed messageId,
        address indexed receiver,
        bytes data
    );

    function sendMessage(address _receiver, uint256 _chainId, bytes calldata _data) external {
        messageCount++;
        messagesByChain[_chainId].push(Message({
            sender: msg.sender,
            receiver: _receiver,
            data: _data,
            chainId: _chainId
        }));

        emit MessageSent(messageCount, msg.sender, _receiver, _chainId, _data);
    }

    function receiveMessage(uint256 _messageId, address _receiver, bytes calldata _data) external {
        // In a real-world scenario, this function would be called by a trusted relayer
        // or a cross-chain communication protocol.
        // For a hackathon, we'll simplify this by allowing anyone to "receive" a message,
        // assuming the message has already been proven to be valid on the source chain.

        // Basic check: ensure the receiver is the intended recipient
        // In a real system, you'd also verify the message's origin and integrity.
        require(_receiver == msg.sender, "CrossChainMessenger: Only intended receiver can claim message");

        // In a real system, you'd need a mechanism to track which messages have been received
        // to prevent double-spending or replay attacks. For this hackathon version,
        // we'll omit that complexity.

        emit MessageReceived(_messageId, _receiver, _data);
    }

    // This function is for demonstration purposes to allow checking messages on the source chain.
    // In a real cross-chain scenario, the receiving chain wouldn't query the sending chain directly like this.
    function getMessage(uint256 _chainId, uint256 _index) external view returns (Message memory) {
        require(_index < messagesByChain[_chainId].length, "CrossChainMessenger: Message index out of bounds");
        return messagesByChain[_chainId][_index];
    }

    function getMessageCountForChain(uint256 _chainId) external view returns (uint256) {
        return messagesByChain[_chainId].length;
    }
}