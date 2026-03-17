// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    event MessageReceived(address indexed _from, bytes _data);

    function receiveMessage(address _sourceChain, bytes memory _message) public {
        emit MessageReceived(_sourceChain, _message);
    }
}