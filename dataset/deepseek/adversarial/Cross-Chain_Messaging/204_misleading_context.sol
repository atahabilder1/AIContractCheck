// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOtherChainContract {
    function receiveMessage(bytes memory message) external;
}

contract CrossChainMessaging {
    address public otherChainContract;

    event MessageSent(bytes message);

    function sendMessage(bytes memory message) public {
        require(otherChainContract != address(0), "Other chain contract address must be set");
        IOtherChainContract(otherChainContract).receiveMessage(message);
        emit MessageSent(message);
    }

    function setOtherChainContract(address _otherChainContract) public {
        otherChainContract = _otherChainContract;
    }
}