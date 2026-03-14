// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    address private _sender;
    address private _receiver;

    event MessageSent(address indexed sender, address indexed receiver, bytes message);

    constructor(address sender, address receiver) public {
        _sender = sender;
        _receiver = receiver;
    }

    function sendMessage(bytes memory message) public {
        emit MessageSent(_sender, _receiver, message);
    }

    function receiveMessage() public {
        bytes memory message = new bytes(1024);
        emit MessageSent(_sender, _receiver, message);
    }
}