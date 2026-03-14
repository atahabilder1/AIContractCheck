// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public owner;
    mapping(bytes32 => bool) public processedTransactions;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TransactionProcessed(bytes32 indexed transactionId, address indexed recipient, uint256 amount, string sourceChain);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function processTransaction(
        bytes32 transactionId,
        address recipient,
        uint256 amount,
        string memory sourceChain
    ) external onlyOwner {
        require(!processedTransactions[transactionId], "Transaction already processed");
        require(amount > 0, "Amount must be greater than zero");
        require(recipient != address(0), "Invalid recipient address");

        processedTransactions[transactionId] = true;
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");

        emit TransactionProcessed(transactionId, recipient, amount, sourceChain);
    }

    receive() external payable {}

    fallback() external payable {}
}