// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract QuickBridge is Ownable {
    // Mapping to store locked tokens for each chain and user
    mapping(uint256 => mapping(address => uint256)) public lockedTokens;
    // Mapping to track the chain ID of the originating chain for a transaction
    mapping(bytes32 => uint256) public originatingChainId;

    // Event emitted when tokens are locked on this chain
    event TokensLocked(address indexed user, address indexed token, uint256 amount, uint256 destinationChainId, bytes32 transactionId);
    // Event emitted when tokens are released on this chain (after being sent from another chain)
    event TokensReleased(address indexed recipient, address indexed token, uint256 amount, bytes32 transactionId);

    // Function to lock tokens on this chain and initiate a transfer to another chain
    function lockTokens(address _tokenAddress, uint256 _amount, uint256 _destinationChainId, bytes32 _transactionId) external {
        require(_amount > 0, "Amount must be greater than zero");
        require(_destinationChainId != block.chainid, "Cannot bridge to the same chain");

        IERC20 token = IERC20(_tokenAddress);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");

        // Transfer tokens from user to the bridge contract
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        // Store locked amount for the user
        lockedTokens[block.chainid][msg.sender] += _amount;

        // Record the originating chain ID for this transaction ID
        originatingChainId[_transactionId] = block.chainid;

        emit TokensLocked(msg.sender, _tokenAddress, _amount, _destinationChainId, _transactionId);
    }

    // Function to release tokens on this chain after they were locked on another chain
    // This function should be called by a trusted relayer or a multi-sig on this chain
    function releaseTokens(address _recipient, address _tokenAddress, uint256 _amount, bytes32 _transactionId) external onlyOwner {
        // Verify that the transaction originated from the expected chain
        // In a real-world scenario, you'd have more robust verification (e.g., message signatures from the source chain)
        require(originatingChainId[_transactionId] != 0, "Invalid transaction ID or originating chain not recorded");
        require(originatingChainId[_transactionId] != block.chainid, "Transaction originated from the same chain");

        // Note: In a real bridge, you'd check if the tokens were actually locked on the originating chain.
        // For this quick hackathon version, we're trusting the `onlyOwner` call.

        IERC20 token = IERC20(_tokenAddress);
        // Ensure the bridge contract has enough tokens to release
        require(token.balanceOf(address(this)) >= _amount, "Bridge contract has insufficient tokens");

        // Transfer tokens to the recipient
        require(token.transfer(_recipient, _amount), "Token transfer failed");

        emit TokensReleased(_recipient, _tokenAddress, _amount, _transactionId);
    }

    // Function to withdraw locked tokens if a transaction failed or was cancelled (requires relayer confirmation)
    // This is a simplified version. A real bridge would have a more complex withdrawal/refund mechanism.
    function withdrawLockedTokens(address _tokenAddress, uint256 _amount, bytes32 _transactionId) external onlyOwner {
        // This function is a placeholder for a more robust refund mechanism.
        // In a real bridge, this would likely involve a timeout and proof of failed transaction.
        // For now, we'll assume `onlyOwner` can initiate a refund.

        require(lockedTokens[block.chainid][msg.sender] >= _amount, "Insufficient locked tokens for withdrawal");
        require(originatingChainId[_transactionId] == block.chainid, "Transaction did not originate from this chain");

        lockedTokens[block.chainid][msg.sender] -= _amount;
        IERC20 token = IERC20(_tokenAddress);
        require(token.transfer(msg.sender, _amount), "Token transfer failed");
    }

    // Fallback function to receive native currency (if needed for gas on other chains)
    receive() external payable {}
}