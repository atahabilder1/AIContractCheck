// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenBridge {
    address public owner;
    IERC20 public token;
    address public recipientChainTokenAddress; // Address of the same token on the recipient chain

    event TokensLocked(address indexed user, uint256 amount);
    event TokensMinted(address indexed user, uint256 amount); // Event emitted to signal minting on the recipient chain

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _tokenAddress, address _recipientChainTokenAddress) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        recipientChainTokenAddress = _recipientChainTokenAddress;
    }

    /**
     * @notice Locks tokens on this chain and emits an event to signal minting on the recipient chain.
     * @dev The user must have approved this contract to spend their tokens beforehand.
     * @param _amount The amount of tokens to lock and mint on the recipient chain.
     */
    function lockAndInitiateMint(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");

        // Transfer tokens from the user to this contract
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

        // Emit an event that can be listened to by a relayer/off-chain service
        // This event signals that tokens have been locked and minting should occur on the recipient chain.
        emit TokensLocked(msg.sender, _amount);
    }

    /**
     * @notice This function would typically be called by a relayer/off-chain service
     *         after verifying the TokensLocked event and minting tokens on the recipient chain.
     *         For this basic example, it's here to demonstrate the flow.
     * @dev In a real-world scenario, this might involve more complex cross-chain communication mechanisms.
     * @param _recipient The address on the recipient chain that will receive the minted tokens.
     * @param _amount The amount of tokens to mint on the recipient chain.
     */
    function mintTokensOnRecipientChain(address _recipient, uint256 _amount) external {
        // In a real implementation, you'd likely have a mechanism to verify
        // that this call is authorized (e.g., by a trusted relayer or a specific signature).
        // For this basic example, we'll emit an event.

        // We are not actually minting tokens here as that would require
        // the IERC20 interface on the recipient chain, which might be a different contract.
        // This event signifies that the minting *should* happen.
        emit TokensMinted(_recipient, _amount);
    }

    // --- Owner functions ---

    function setRecipientChainTokenAddress(address _recipientChainTokenAddress) external onlyOwner {
        recipientChainTokenAddress = _recipientChainTokenAddress;
    }

    function withdrawStuckTokens(address _tokenAddress, address _to, uint256 _amount) external onlyOwner {
        IERC20 tokenToWithdraw = IERC20(_tokenAddress);
        bool success = tokenToWithdraw.transfer(_to, _amount);
        require(success, "Withdrawal failed");
    }
}