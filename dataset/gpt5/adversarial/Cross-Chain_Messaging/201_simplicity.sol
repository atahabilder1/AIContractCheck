// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrossChainReceiver {
    function onCrossChainMessage(uint256 srcChainId, address srcSender, bytes calldata message) external;
}

contract SimpleCrossChainMessenger {
    event MessageSent(uint256 indexed dstChainId, address indexed to, bytes message);

    function sendMessage(uint256 dstChainId, address to, bytes calldata message) external {
        emit MessageSent(dstChainId, to, message);
    }

    function deliverMessage(address to, uint256 srcChainId, address srcSender, bytes calldata message) external {
        ICrossChainReceiver(to).onCrossChainMessage(srcChainId, srcSender, message);
    }
}