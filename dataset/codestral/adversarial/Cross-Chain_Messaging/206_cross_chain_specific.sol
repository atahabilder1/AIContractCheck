// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    struct Message {
        address sender;
        uint256 nonce;
        bytes data;
    }

    event NewMessage(address indexed sender, uint256 indexed nonce, bytes data);

    function sendMessage(address _receiverChain, bytes memory _data) public {
        Message memory newMessage = Message({
            sender: msg.sender,
            nonce: msg.nonce,
            data: _data
        });

        emit NewMessage(newMessage.sender, newMessage.nonce, newMessage.data);
    }
}