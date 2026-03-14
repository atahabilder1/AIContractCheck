// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address[] public validators;
    uint256 public consensusThreshold;
    mapping(address => bool) public isValidator;
    mapping(address => uint256) public lastMessageTimestamp;
    mapping(address => uint256) public messageCount;
    mapping(bytes32 => bool) public messageExists;
    mapping(bytes32 => uint256) public messageTimestamp;

    event MessageReceived(address indexed sender, bytes32 indexed message);

    constructor(address[] memory _validators, uint256 _consensusThreshold) {
        validators = _validators;
        consensusThreshold = _consensusThreshold;
        for (uint256 i = 0; i < _validators.length; i++) {
            isValidator[_validators[i]] = true;
        }
    }

    function receiveMessage(bytes32 _message) external {
        require(isValidator[msg.sender], "Only validators can send messages");
        require(block.timestamp > lastMessageTimestamp[msg.sender], "Messages must be received in order");
        require(messageCount[msg.sender] < consensusThreshold, "Validator has already reached consensus");
        require(!messageExists[_message], "Message has already been received");

        messageExists[_message] = true;
        messageTimestamp[_message] = block.timestamp;
        messageCount[msg.sender]++;

        emit MessageReceived(msg.sender, _message);
    }

    function getMessageCount(bytes32 _message) external view returns (uint256) {
        return messageCount[_message];
    }

    function getLastMessageTimestamp(bytes32 _message) external view returns (uint256) {
        return messageTimestamp[_message];
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    function getConsensusThreshold() external view returns (uint256) {
        return consensusThreshold;
    }
}