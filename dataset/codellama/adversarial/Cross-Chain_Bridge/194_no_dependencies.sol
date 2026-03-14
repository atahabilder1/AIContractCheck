// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(address => bool) public isBridge;

    constructor() public {
        owner = msg.sender;
    }

    function setBridge(address bridge) public {
        require(msg.sender == owner, "Only the owner can set the bridge");
        isBridge[bridge] = true;
    }

    function removeBridge(address bridge) public {
        require(msg.sender == owner, "Only the owner can remove the bridge");
        isBridge[bridge] = false;
    }

    function isBridged(address from, address to) public view returns (bool) {
        return isBridge[from] && isBridge[to];
    }
}