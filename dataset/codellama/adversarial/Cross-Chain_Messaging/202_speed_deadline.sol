// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    address private _owner;
    mapping(address => string[]) private _messages;

    event MessageSent(address indexed sender, string message);

    constructor() public {
        _owner = msg.sender;
    }

    function sendMessage(string calldata message) external {
        require(msg.sender == _owner, "Only the owner can send messages");
        _messages[msg.sender].push(message);
        emit MessageSent(msg.sender, message);
    }

    function getMessages() external view returns (string[] memory) {
        return _messages[msg.sender];
    }
}