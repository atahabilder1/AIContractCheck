pragma solidity ^0.8.0;

contract CrossChainMessaging {
    struct Message {
        address sender;
        address recipient;
        string message;
    }

    mapping (address => mapping (address => Message[])) public messages;

    event NewMessage(address indexed sender, address indexed recipient, string message);

    function sendMessage(address recipient, string memory message) public {
        Message memory newMessage = Message({
            sender: msg.sender,
            recipient: recipient,
            message: message
        });

        messages[msg.sender][recipient].push(newMessage);

        emit NewMessage(msg.sender, recipient, message);
    }

    function getMessages(address sender, address recipient) public view returns (Message[] memory) {
        return messages[sender][recipient];
    }

    function getMessageCount(address sender, address recipient) public view returns (uint) {
        return messages[sender][recipient].length;
    }
}