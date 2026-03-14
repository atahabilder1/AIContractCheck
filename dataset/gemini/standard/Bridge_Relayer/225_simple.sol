// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BasicBridgeRelayer {

    address public owner;
    mapping(address => bool) public authorizedRelayers;
    mapping(uint256 => bytes) public storedMessages;
    uint256 public messageCounter;

    event MessageStored(uint256 indexed messageId, address indexed sender, bytes message);
    event MessageForwarded(uint256 indexed messageId, address indexed destination);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyAuthorizedRelayer() {
        require(authorizedRelayers[msg.sender], "Caller is not an authorized relayer");
        _;
    }

    constructor() {
        owner = msg.sender;
        messageCounter = 0;
    }

    function addAuthorizedRelayer(address _relayer) public onlyOwner {
        authorizedRelayers[_relayer] = true;
    }

    function removeAuthorizedRelayer(address _relayer) public onlyOwner {
        authorizedRelayers[_relayer] = false;
    }

    function storeMessage(bytes memory _message) public onlyAuthorizedRelayer {
        messageCounter++;
        storedMessages[messageCounter] = _message;
        emit MessageStored(messageCounter, msg.sender, _message);
    }

    function forwardMessage(uint256 _messageId, address _destination) public onlyAuthorizedRelayer {
        require(_messageId > 0 && _messageId <= messageCounter, "Invalid message ID");
        require(bytes(storedMessages[_messageId]).length > 0, "Message not found or already forwarded");

        bytes memory message = storedMessages[_messageId];
        // In a real bridge, this would involve calling a cross-chain communication primitive.
        // For this basic example, we'll just emit an event.
        emit MessageForwarded(_messageId, _destination);

        // Optionally, you might want to clear the stored message after forwarding
        // to prevent re-forwarding or to save gas if storage is expensive.
        // delete storedMessages[_messageId];
    }

    function getMessage(uint256 _messageId) public view returns (bytes memory) {
        require(_messageId > 0 && _messageId <= messageCounter, "Invalid message ID");
        return storedMessages[_messageId];
    }
}