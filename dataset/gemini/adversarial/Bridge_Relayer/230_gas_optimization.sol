// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public owner;
    mapping(uint256 => bool) public processedMessages;

    event MessageRelayed(uint256 indexed messageId, address indexed sender, bytes data);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function relayMessage(uint256 _messageId, address _sender, bytes calldata _data) external onlyOwner {
        require(!processedMessages[_messageId], "Message already processed");

        processedMessages[_messageId] = true;
        emit MessageRelayed(_messageId, _sender, _data);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }
}