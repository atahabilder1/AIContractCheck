// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrossChainBridge {
    address public admin;
    mapping(bytes32 => bool) public processedMessages;

    event TransferInitialized(address indexed sender, address indexed receiver, uint256 amount, bytes32 indexed messageId);
    event TransferCompleted(address indexed receiver, uint256 amount, bytes32 indexed messageId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function initializeTransfer(address receiver, uint256 amount, bytes32 messageId) external payable {
        require(msg.value == amount, "Incorrect amount sent");
        emit TransferInitialized(msg.sender, receiver, amount, messageId);
    }

    function completeTransfer(address payable receiver, uint256 amount, bytes32 messageId) external onlyAdmin {
        require(!processedMessages[messageId], "Message already processed");
        processedMessages[messageId] = true;
        receiver.transfer(amount);
        emit TransferCompleted(receiver, amount, messageId);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}