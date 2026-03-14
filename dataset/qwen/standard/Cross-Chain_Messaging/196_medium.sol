// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessagingProtocol {
    struct Message {
        uint256 nonce;
        address sender;
        bytes payload;
        uint256 gasLimit;
        bool executed;
    }

    mapping(uint256 => Message) public messages;
    uint256 public lastNonce;
    address public sourceChainVerifier;

    event MessageSent(uint256 indexed nonce, address indexed sender, bytes payload, uint256 gasLimit);
    event MessageExecuted(uint256 indexed nonce);

    modifier onlySourceChainVerifier() {
        require(msg.sender == sourceChainVerifier, "Not authorized");
        _;
    }

    constructor(address _sourceChainVerifier) {
        sourceChainVerifier = _sourceChainVerifier;
    }

    function sendMessage(bytes memory _payload, uint256 _gasLimit) external {
        lastNonce++;
        messages[lastNonce] = Message(lastNonce, msg.sender, _payload, _gasLimit, false);
        emit MessageSent(lastNonce, msg.sender, _payload, _gasLimit);
    }

    function executeMessage(uint256 _nonce) external onlySourceChainVerifier {
        Message storage message = messages[_nonce];
        require(!message.executed, "Message already executed");
        require(gasleft() >= message.gasLimit, "Insufficient gas for execution");

        (bool success, ) = message.sender.call{gas: message.gasLimit}(message.payload);
        require(success, "Message execution failed");

        message.executed = true;
        emit MessageExecuted(_nonce);
    }

    function setSourceChainVerifier(address _newVerifier) external onlySourceChainVerifier {
        require(_newVerifier != address(0), "Invalid address");
        sourceChainVerifier = _newVerifier;
    }
}