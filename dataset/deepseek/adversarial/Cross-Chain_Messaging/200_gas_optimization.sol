// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOtherChainContract {
    function receiveMessage(bytes32 messageHash) external;
}

contract CrossChainMessenger {
    address public immutable otherChainContract;

    constructor(address _otherChainContract) {
        otherChainContract = _otherChainContract;
    }

    function sendMessage(bytes32 messageHash) external {
        IOtherChainContract(otherChainContract).receiveMessage(messageHash);
    }
}