// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    struct Message {
        address sender;
        string content;
    }

    Message[] public messages;
    uint256 public batchSize;
    address public relayContract;

    event MessageBatched(address indexed sender, string content);
    event BatchSent(uint256 batchSize, address indexed relayContract);

    modifier onlyRelayContract() {
        require(msg.sender == relayContract, "Only relay contract can call this function");
        _;
    }

    constructor(uint256 _batchSize, address _relayContract) {
        batchSize = _batchSize;
        relayContract = _relayContract;
    }

    function addMessage(string calldata content) external {
        messages.push(Message(msg.sender, content));
        emit MessageBatched(msg.sender, content);

        if (messages.length >= batchSize) {
            sendBatch();
        }
    }

    function sendBatch() public onlyRelayContract {
        require(messages.length > 0, "No messages to send");

        // Logic to send messages to another chain could go here

        emit BatchSent(messages.length, relayContract);

        // Clear the messages array after sending
        delete messages;
    }

    function updateRelayContract(address newRelayContract) external onlyRelayContract {
        relayContract = newRelayContract;
    }

    function updateBatchSize(uint256 newBatchSize) external onlyRelayContract {
        batchSize = newBatchSize;
    }

    function getMessages() external view returns (Message[] memory) {
        return messages;
    }
}