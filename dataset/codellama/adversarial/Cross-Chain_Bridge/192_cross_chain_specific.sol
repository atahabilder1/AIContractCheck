// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public sourceChain;
    mapping(address => mapping(bytes32 => bool)) public isTrusted;

    event TrustAdded(address indexed account, bytes32 indexed hash);
    event TrustRemoved(address indexed account, bytes32 indexed hash);

    constructor(address _sourceChain) public {
        sourceChain = _sourceChain;
    }

    function addTrust(address account, bytes32 hash) public {
        require(msg.sender == sourceChain, "Only source chain can add trust");
        isTrusted[account][hash] = true;
        emit TrustAdded(account, hash);
    }

    function removeTrust(address account, bytes32 hash) public {
        require(msg.sender == sourceChain, "Only source chain can remove trust");
        isTrusted[account][hash] = false;
        emit TrustRemoved(account, hash);
    }
}