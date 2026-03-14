// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {

    address public owner;
    mapping(uint256 => bool) public usedHashes;
    uint256 public nextNonce;

    event Deposit(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed recipient, uint256 amount, uint256 timestamp);
    event Lock(address indexed sender, uint256 amount, bytes32 messageHash, uint256 timestamp);
    event Unlock(address indexed recipient, uint256 amount, bytes32 messageHash, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextNonce = 0;
    }

    // Function to allow users to deposit Ether into the bridge
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    // Function to allow the owner (or designated relayer) to withdraw Ether
    // This function assumes a mechanism exists off-chain to verify the withdrawal request
    // and that the owner is trusted to execute valid withdrawals.
    function withdraw(address payable _recipient, uint256 _amount) public onlyOwner {
        require(_recipient != address(0), "Recipient address cannot be zero");
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(address(this).balance >= _amount, "Insufficient balance in the bridge");

        (bool success, ) = _recipient.call{value: _amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawal(_recipient, _amount, block.timestamp);
    }

    // Function to lock assets on one chain for a cross-chain transfer
    // This function would typically be called after a user initiates a transfer
    // and the asset is locked on the source chain.
    function lock(bytes32 _messageHash) public payable {
        require(msg.value > 0, "Amount to lock must be greater than 0");
        require(!usedHashes[_messageHash], "Message hash has already been used");

        // In a real-world scenario, you would store the locked amount associated with the sender and messageHash
        // and implement logic to prevent double-spending. For this example, we'll just emit an event.

        emit Lock(msg.sender, msg.value, _messageHash, block.timestamp);
    }

    // Function to unlock assets on the destination chain after verification
    // This function would be called by a trusted relayer or a governance mechanism
    // after verifying the original lock event on the source chain.
    function unlock(address _recipient, uint256 _amount, bytes32 _messageHash) public {
        require(_recipient != address(0), "Recipient address cannot be zero");
        require(_amount > 0, "Unlock amount must be greater than 0");
        require(!usedHashes[_messageHash], "Message hash has already been used");

        // In a real-world scenario, this function would be protected by a more robust
        // verification mechanism (e.g., signatures from multiple validators).
        // For simplicity, we assume the caller is authorized to unlock if the hash is not used.

        // In a real bridge, you'd ensure the contract has enough balance to fulfill the unlock.
        // This example assumes the locked amount is available to be sent.

        (bool success, ) = _recipient.call{value: _amount}("");
        require(success, "Unlock failed");

        usedHashes[_messageHash] = true;
        emit Unlock(_recipient, _amount, _messageHash, block.timestamp);
    }

    // Function to update the owner (for ownership transfer)
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "New owner cannot be the zero address");
        owner = _newOwner;
    }

    // Fallback function to receive Ether directly
    receive() external payable {
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }
}