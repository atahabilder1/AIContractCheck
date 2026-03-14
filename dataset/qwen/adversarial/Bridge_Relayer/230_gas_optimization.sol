// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeRelayer {
    address public immutable bridge;

    constructor(address _bridge) {
        bridge = _bridge;
    }

    function relayMessage(bytes memory data) external {
        require(msg.sender == bridge, "Unauthorized");
        (bool success, ) = bridge.call(data);
        require(success, "Call failed");
    }
}