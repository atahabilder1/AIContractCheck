// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageReceiver {
    function receiveMessage(bytes32 messageHash) external;
}

contract CrossChainMessenger {
    address public immutable sender;
    address public immutable receiver;

    constructor(address _receiver) {
        sender = msg.sender;
        receiver = _receiver;
    }

    function sendMessage(bytes memory message) public {
        require(msg.sender == sender, "Only sender can send messages");
        bytes32 messageHash = keccak256(message);
        IMessageReceiver(receiver).receiveMessage(messageHash);
    }
}