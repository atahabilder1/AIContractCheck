// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrossChainBridge {
    address public owner;
    mapping(uint256 => bool) public processedNonces;

    event TransferInitiated(address indexed sender, uint256 amount, uint256 nonce, uint256 timestamp);
    event TransferReceived(address indexed receiver, uint256 amount, uint256 nonce, uint256 timestamp);

    constructor() {
        owner = msg.sender;
    }

    function initiateTransfer(address receiver, uint256 amount, uint256 nonce) external payable {
        require(msg.value == amount, "Amount sent does not match the specified amount");
        emit TransferInitiated(msg.sender, amount, nonce, block.timestamp);
    }

    function receiveTransfer(address receiver, uint256 amount, uint256 nonce) external {
        require(msg.sender == owner, "Only the owner can receive transfers");
        require(!processedNonces[nonce], "Transfer already processed");
        processedNonces[nonce] = true;
        payable(receiver).transfer(amount);
        emit TransferReceived(receiver, amount, nonce, block.timestamp);
    }
}