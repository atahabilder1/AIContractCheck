// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CrossChainBridge {
    address public immutable owner;
    mapping(bytes32 => bool) public usedNonces;

    event TransferInitiated(address indexed sender, address indexed receiver, uint256 amount, uint256 nonce, bytes32 indexed txHash);
    event TransferCompleted(address indexed receiver, uint256 amount, bytes32 indexed txHash);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function initiateTransfer(address receiver, uint256 amount, uint256 nonce) external payable {
        bytes32 txHash = keccak256(abi.encodePacked(receiver, amount, nonce, msg.sender));
        require(!usedNonces[txHash], "Nonce already used");
        usedNonces[txHash] = true;
        require(msg.value == amount, "Invalid amount");

        emit TransferInitiated(msg.sender, receiver, amount, nonce, txHash);
    }

    function completeTransfer(address receiver, uint256 amount, bytes32 txHash) external onlyOwner {
        require(!usedNonces[txHash], "Transfer already completed");
        usedNonces[txHash] = true;

        (bool success, ) = receiver.call{value: amount}("");
        require(success, "Transfer failed");

        emit TransferCompleted(receiver, amount, txHash);
    }

    receive() external payable {}
}