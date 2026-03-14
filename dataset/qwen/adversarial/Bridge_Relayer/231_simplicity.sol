// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleBridgeRelayer {
    address public bridge;

    constructor(address _bridge) {
        bridge = _bridge;
    }

    function relayMessage(bytes memory message) external {
        require(msg.sender == bridge, "Unauthorized");
        // Assume message handling logic here
    }
}