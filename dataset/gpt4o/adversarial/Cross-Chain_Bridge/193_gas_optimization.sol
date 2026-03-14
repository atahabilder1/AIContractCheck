// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract CrossChainBridge {
    address public owner;
    mapping(address => mapping(uint256 => bool)) public processedNonces;

    event Transfer(address indexed from, address to, uint256 amount, uint256 date, uint256 nonce, bytes32 hash);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transfer(address to, uint256 amount, uint256 nonce, uint256 chainId) external {
        require(!processedNonces[msg.sender][nonce], "Transfer already processed");
        processedNonces[msg.sender][nonce] = true;

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, to, amount, nonce, chainId));
        emit Transfer(msg.sender, to, amount, block.timestamp, nonce, hash);
    }

    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}