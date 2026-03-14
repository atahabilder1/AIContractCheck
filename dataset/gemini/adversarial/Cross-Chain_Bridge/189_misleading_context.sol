// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestnetBridge is Ownable {

    // Mapping from chain ID to the address of the bridge contract on that chain
    mapping(uint256 => address) public peerBridges;

    // Mapping from a unique transaction ID to a boolean indicating if it has been processed
    mapping(bytes32 => bool) public processedTransactions;

    // Event emitted when tokens are locked on this chain
    event TokensLocked(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destinationChainId,
        bytes32 transactionId
    );

    // Event emitted when tokens are unlocked on this chain
    event TokensUnlocked(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 transactionId
    );

    // The ERC20 token contract this bridge will manage
    IERC20 public immutable token;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    /**
     * @notice Sets the address of the bridge contract on a peer chain.
     * @param _chainId The chain ID of the peer chain.
     * @param _bridgeAddress The address of the bridge contract on the peer chain.
     */
    function setPeerBridge(uint256 _chainId, address _bridgeAddress) public onlyOwner {
        peerBridges[_chainId] = _bridgeAddress;
    }

    /**
     * @notice Locks tokens on this chain to be transferred to another chain.
     * @dev The sender must approve the bridge contract to spend their tokens.
     * @param _recipient The address on the destination chain that will receive the tokens.
     * @param _amount The amount of tokens to lock.
     * @param _destinationChainId The chain ID of the destination chain.
     * @param _transactionId A unique identifier for this cross-chain transaction.
     */
    function lockTokens(
        address _recipient,
        uint256 _amount,
        uint256 _destinationChainId,
        bytes32 _transactionId
    ) public {
        require(peerBridges[_destinationChainId] != address(0), "Peer bridge not set for destination chain");
        require(_amount > 0, "Amount must be greater than zero");
        require(!processedTransactions[_transactionId], "Transaction ID already processed");

        // Transfer tokens from the sender to the bridge contract
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        // Mark transaction as processed
        processedTransactions[_transactionId] = true;

        emit TokensLocked(msg.sender, _recipient, _amount, _destinationChainId, _transactionId);
    }

    /**
     * @notice Unlocks tokens on this chain, typically after they have been locked on another chain.
     * @dev This function should only be called by a trusted relayer or the peer bridge contract.
     * @param _recipient The address on this chain that will receive the tokens.
     * @param _amount The amount of tokens to unlock.
     * @param _sourceChainId The chain ID of the source chain where tokens were locked.
     * @param _transactionId A unique identifier for this cross-chain transaction.
     */
    function unlockTokens(
        address _recipient,
        uint256 _amount,
        uint256 _sourceChainId,
        bytes32 _transactionId
    ) public {
        // In a real-world scenario, you'd have more robust checks here,
        // like verifying the sender is a trusted relayer or the peer bridge.
        // For this testnet version, we'll rely on the onlyOwner for simplicity
        // or assume a trusted external caller.
        // For a more robust testnet, you might add a `relayer` role.

        require(peerBridges[_sourceChainId] != address(0), "Peer bridge not set for source chain");
        require(_amount > 0, "Amount must be greater than zero");
        require(!processedTransactions[_transactionId], "Transaction ID already processed");

        // Mark transaction as processed
        processedTransactions[_transactionId] = true;

        // Transfer tokens from the bridge contract to the recipient
        require(token.transfer(_recipient, _amount), "Token transfer failed");

        emit TokensUnlocked(msg.sender, _recipient, _amount, _sourceChainId, _transactionId);
    }

    /**
     * @notice Allows the owner to withdraw any accidentally sent tokens to the bridge contract.
     * @param _tokenAddress The address of the ERC20 token to withdraw.
     * @param _to The address to send the tokens to.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawStuckTokens(address _tokenAddress, address _to, uint256 _amount) public onlyOwner {
        IERC20 stuckToken = IERC20(_tokenAddress);
        require(stuckToken.balanceOf(address(this)) >= _amount, "Insufficient balance of stuck tokens");
        require(stuckToken.transfer(_to, _amount), "Stuck token transfer failed");
    }
}