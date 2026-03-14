// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public owner;
    mapping(bytes32 => bool) public processedTransactions;

    event Relayed(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        bytes32 indexed transactionHash
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function relay(
        address receiver,
        uint256 amount,
        bytes32 transactionHash
    ) external onlyOwner {
        require(!processedTransactions[transactionHash], "Transaction already processed");

        processedTransactions[transactionHash] = true;

        (bool success, ) = receiver.call{value: amount}("");
        require(success, "Transfer failed");

        emit Relayed(msg.sender, receiver, amount, transactionHash);
    }

    receive() external payable {}
}