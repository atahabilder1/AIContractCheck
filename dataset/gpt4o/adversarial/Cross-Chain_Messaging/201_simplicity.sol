// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrossChainMessenger {
    event MessageSent(address indexed from, string message, uint256 destinationChainId);

    function sendMessage(string calldata message, uint256 destinationChainId) external {
        emit MessageSent(msg.sender, message, destinationChainId);
    }
}