// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public bridgeAdmin;

    event MessageRelayed(address indexed destination, uint256 indexed nonce, bytes data);

    constructor(address _bridgeAdmin) {
        bridgeAdmin = _bridgeAdmin;
    }

    function relayMessage(address destination, uint256 nonce, bytes calldata data) external {
        require(msg.sender == bridgeAdmin, "Unauthorized");
        emit MessageRelayed(destination, nonce, data);
    }
}