// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MessageProtocol {
    struct Message {
        address sender;
        string message;
    }

    mapping(address => mapping(address => bool)) public trustedSources;

    event NewMessage(address sender, string message);

    function sendMessage(address receiver, string memory message) public {
        require(trustedSources[msg.sender][receiver], "Sender is not trusted by receiver");
        emit NewMessage(msg.sender, message);
    }
}