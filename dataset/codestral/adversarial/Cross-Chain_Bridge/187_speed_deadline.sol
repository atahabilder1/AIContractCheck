// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address payable public recipient;

    constructor(address payable _recipient) {
        recipient = _recipient;
    }

    function deposit() external payable {
        // This is a placeholder for the actual cross-chain transfer logic.
        // In a real scenario, you would need to implement a secure and reliable mechanism for transferring assets between chains.
        uint amount = msg.value;
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed.");
    }
}