// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleBridgeRelayer {
    address public owner;
    mapping(bytes32 => bool) public processedTransactions;

    event TransactionRelayed(bytes32 indexed transactionHash, address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function relayTransaction(
        bytes32 transactionHash,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(!processedTransactions[transactionHash], "Transaction already processed");
        
        processedTransactions[transactionHash] = true;

        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");

        emit TransactionRelayed(transactionHash, to, amount);
    }

    receive() external payable {}
}