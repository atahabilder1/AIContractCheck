// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic Cross-Chain Bridge
contract BasicBridge {
    address public token;
    address public relayer;
    uint256 public nonce;

    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public lockedBalance;

    event TokensLocked(address indexed user, uint256 amount, uint256 targetChain, uint256 nonce);
    event TokensUnlocked(address indexed user, uint256 amount, bytes32 messageId);
    event TokensMinted(address indexed user, uint256 amount, bytes32 messageId);
    event TokensBurned(address indexed user, uint256 amount, uint256 targetChain, uint256 nonce);

    constructor(address _token, address _relayer) {
        token = _token;
        relayer = _relayer;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Only relayer");
        _;
    }

    // Lock tokens on source chain
    function lockTokens(uint256 amount, uint256 targetChain) external {
        require(amount > 0, "Amount must be > 0");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        lockedBalance[msg.sender] += amount;
        nonce++;
        emit TokensLocked(msg.sender, amount, targetChain, nonce);
    }

    // Unlock tokens on source chain (when bridging back)
    function unlockTokens(address user, uint256 amount, bytes32 messageId) external onlyRelayer {
        require(!processedMessages[messageId], "Already processed");
        processedMessages[messageId] = true;
        lockedBalance[user] -= amount;
        IERC20(token).transfer(user, amount);
        emit TokensUnlocked(user, amount, messageId);
    }

    // Mint tokens on destination chain
    function mintTokens(address user, uint256 amount, bytes32 messageId) external onlyRelayer {
        require(!processedMessages[messageId], "Already processed");
        processedMessages[messageId] = true;
        IMintable(token).mint(user, amount);
        emit TokensMinted(user, amount, messageId);
    }

    // Burn tokens on destination chain (to bridge back)
    function burnTokens(uint256 amount, uint256 targetChain) external {
        require(amount > 0, "Amount must be > 0");
        IBurnable(token).burnFrom(msg.sender, amount);
        nonce++;
        emit TokensBurned(msg.sender, amount, targetChain, nonce);
    }

    function setRelayer(address _relayer) external {
        require(msg.sender == relayer, "Only relayer");
        relayer = _relayer;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IMintable {
    function mint(address to, uint256 amount) external;
}

interface IBurnable {
    function burnFrom(address from, uint256 amount) external;
}
