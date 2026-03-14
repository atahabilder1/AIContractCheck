// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCrossChainBridge {

    address public owner;
    mapping(uint256 => bool) public processedTransactions; // To prevent replaying transactions

    event FundsDeposited(address indexed user, uint256 amount, uint256 sourceChainTxId);
    event FundsWithdrawn(address indexed user, uint256 amount, uint256 destinationChainTxId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Function to be called on the source chain to deposit funds
    // This function would typically emit an event that a relayer monitors
    function deposit(uint256 _sourceChainTxId) public payable {
        require(!processedTransactions[_sourceChainTxId], "Transaction already processed");
        processedTransactions[_sourceChainTxId] = true;

        emit FundsDeposited(msg.sender, msg.value, _sourceChainTxId);
    }

    // Function to be called on the destination chain by a relayer
    // This function trusts the data from the source chain's event.
    // In a real-world scenario, a relayer would monitor events on the source chain
    // and call this function on the destination chain with the event data.
    function withdraw(address _user, uint256 _amount, uint256 _sourceChainTxId, uint256 _destinationChainTxId) public onlyOwner {
        // Basic check to ensure the source transaction was processed and we are not replaying
        require(processedTransactions[_sourceChainTxId], "Source transaction not processed or invalid");

        // In a truly trustless bridge, this would involve complex verification.
        // Here, we are trusting the relayer and the source chain data.
        // The _sourceChainTxId is used to prevent re-entrancy and replay attacks
        // from the same source transaction.

        // Transfer funds to the user on the destination chain
        (bool success, ) = payable(_user).call{value: _amount}("");
        require(success, "Fund transfer failed");

        emit FundsWithdrawn(_user, _amount, _destinationChainTxId);
    }

    // Owner can withdraw funds from the contract if needed (e.g., for maintenance)
    function ownerWithdraw(uint256 _amount) public onlyOwner {
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Owner withdrawal failed");
    }

    // Function to allow the owner to change the owner
    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    // Fallback function to receive Ether
    receive() external payable {}
}