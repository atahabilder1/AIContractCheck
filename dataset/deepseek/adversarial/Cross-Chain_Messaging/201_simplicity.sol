// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    address public sender;
    address public receiver;
    string public message;

    function sendMessage(address _receiver, string memory _message) public {
        sender = msg.sender;
        receiver = _receiver;
        message = _message;
    }

    function receiveMessage() public view returns (address, string memory) {
        return (sender, message);
    }
}