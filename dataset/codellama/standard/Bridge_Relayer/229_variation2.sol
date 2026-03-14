// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract BridgeRelayer {
    struct Message {
        address sender;
        address recipient;
        uint256 value;
        uint256 fee;
    }

    mapping(address => uint256) public fees;
    mapping(address => uint256) public priorities;
    mapping(address => Message[]) public messages;

    event MessageAdded(address indexed sender, address indexed recipient, uint256 indexed value, uint256 indexed fee);
    event MessageProcessed(address indexed sender, address indexed recipient, uint256 indexed value, uint256 indexed fee);

    function addMessage(Message memory _message) public {
        messages[_message.recipient].push(_message);
        emit MessageAdded(_message.sender, _message.recipient, _message.value, _message.fee);
    }

    function processMessage(Message memory _message) public {
        require(messages[_message.recipient].length > 0, "No messages to process");
        require(messages[_message.recipient][0].recipient == _message.recipient, "Invalid message recipient");
        require(messages[_message.recipient][0].sender == _message.sender, "Invalid message sender");
        require(messages[_message.recipient][0].value == _message.value, "Invalid message value");
        require(messages[_message.recipient][0].fee == _message.fee, "Invalid message fee");

        delete messages[_message.recipient][0];
        emit MessageProcessed(_message.sender, _message.recipient, _message.value, _message.fee);
    }

    function getMessages(address _recipient) public view returns (Message[] memory) {
        return messages[_recipient];
    }

    function getFees(address _recipient) public view returns (uint256) {
        return fees[_recipient];
    }

    function getPriorities(address _recipient) public view returns (uint256) {
        return priorities[_recipient];
    }

    function setFees(uint256 _fee) public {
        fees[msg.sender] = _fee;
    }

    function setPriorities(uint256 _priority) public {
        priorities[msg.sender] = _priority;
    }
}