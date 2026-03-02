// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Cross-Chain Messaging Contract
contract CrossChainMessaging {
    address public owner;
    address public relayer;
    uint256 public messageNonce;
    uint256 public fee;

    mapping(bytes32 => bool) public processedMessages;
    mapping(uint256 => bool) public supportedChains;

    event MessageSent(
        bytes32 indexed messageId,
        uint256 indexed targetChain,
        address sender,
        address target,
        bytes data,
        uint256 nonce
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint256 indexed sourceChain,
        address sender,
        address target,
        bytes data
    );

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Only relayer");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _relayer, uint256 _fee) {
        owner = msg.sender;
        relayer = _relayer;
        fee = _fee;
    }

    function sendMessage(
        uint256 targetChain,
        address target,
        bytes calldata data
    ) external payable returns (bytes32) {
        require(supportedChains[targetChain], "Chain not supported");
        require(msg.value >= fee, "Insufficient fee");

        messageNonce++;
        bytes32 messageId = keccak256(abi.encode(
            block.chainid,
            targetChain,
            msg.sender,
            target,
            data,
            messageNonce
        ));

        emit MessageSent(messageId, targetChain, msg.sender, target, data, messageNonce);
        return messageId;
    }

    function receiveMessage(
        uint256 sourceChain,
        address sender,
        address target,
        bytes calldata data,
        bytes32 messageId
    ) external onlyRelayer {
        require(!processedMessages[messageId], "Already processed");
        processedMessages[messageId] = true;

        (bool success, ) = target.call(data);
        require(success, "Message execution failed");

        emit MessageReceived(messageId, sourceChain, sender, target, data);
    }

    function addSupportedChain(uint256 chainId) external onlyOwner {
        supportedChains[chainId] = true;
    }

    function removeSupportedChain(uint256 chainId) external onlyOwner {
        supportedChains[chainId] = false;
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
    }

    function withdrawFees() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
