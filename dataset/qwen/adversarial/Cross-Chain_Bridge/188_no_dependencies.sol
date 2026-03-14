// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(bytes32 => bool) public completedTransfers;

    event TransferInitiated(address indexed sender, uint256 amount, bytes32 indexed transferId);
    event TransferCompleted(address indexed receiver, uint256 amount, bytes32 indexed transferId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function initiateTransfer(address receiver, uint256 amount, bytes32 transferId) external payable {
        require(msg.value == amount, "Amount sent does not match the specified transfer amount");
        emit TransferInitiated(msg.sender, amount, transferId);
    }

    function completeTransfer(address receiver, uint256 amount, bytes32 transferId) external onlyOwner {
        require(!completedTransfers[transferId], "Transfer already completed");
        completedTransfers[transferId] = true;
        payable(receiver).transfer(amount);
        emit TransferCompleted(receiver, amount, transferId);
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }
}