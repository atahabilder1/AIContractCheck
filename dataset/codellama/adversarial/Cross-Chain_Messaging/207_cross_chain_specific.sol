// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    address public sourceChain;
    mapping(address => mapping(uint256 => bytes32)) public messages;

    constructor(address _sourceChain) public {
        sourceChain = _sourceChain;
    }

    function sendMessage(uint256 nonce, bytes32 message) public {
        messages[msg.sender][nonce] = message;
    }

    function getMessage(address sender, uint256 nonce) public view returns (bytes32) {
        return messages[sender][nonce];
    }
}