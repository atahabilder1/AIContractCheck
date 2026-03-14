// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TestnetBridgeRelayer {
    address public owner;
    mapping(bytes32 => bool) public processedTransactions;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount, string targetChainAddress);
    event Relay(address indexed user, uint256 amount, string sourceChainAddress, bytes32 transactionId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(string memory targetChainAddress) external payable {
        require(msg.value > 0, "Deposit amount should be greater than zero");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value, targetChainAddress);
    }

    function relay(address user, uint256 amount, string memory sourceChainAddress, bytes32 transactionId) external onlyOwner {
        require(amount > 0, "Relay amount should be greater than zero");
        require(!processedTransactions[transactionId], "Transaction already processed");
        
        processedTransactions[transactionId] = true;
        require(address(this).balance >= amount, "Insufficient balance in the contract");

        payable(user).transfer(amount);
        emit Relay(user, amount, sourceChainAddress, transactionId);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}