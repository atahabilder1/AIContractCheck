// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessenger {
    address payable public otherChainReceiver;

    constructor(address _otherChainReceiver) {
        otherChainReceiver = payable(_otherChainReceiver);
    }

    function sendMessage(bytes memory message, uint256 amount) external payable {
        (bool success, ) = otherChainReceiver.call{value: amount}(message);
        require(success, "Message sending failed");
    }
}