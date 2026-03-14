// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrossChainBridge {
    address public owner;

    event TokensLocked(address indexed sender, uint256 amount, string targetChain, address targetAddress);
    event TokensUnlocked(address indexed receiver, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function lockTokens(uint256 amount, string memory targetChain, address targetAddress) external payable {
        require(msg.value == amount, "Incorrect amount sent");
        emit TokensLocked(msg.sender, amount, targetChain, targetAddress);
    }

    function unlockTokens(address payable receiver, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        receiver.transfer(amount);
        emit TokensUnlocked(receiver, amount);
    }
}