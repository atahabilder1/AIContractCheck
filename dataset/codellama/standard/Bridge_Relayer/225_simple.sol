pragma solidity ^0.6.0;

// SPDX-License-Identifier: MIT

contract BridgeRelayer {
    address[] public authorizedRelayers;
    mapping(address => bool) public isRelayer;
    mapping(bytes32 => bool) public processedMessages;

    event MessageForwarded(bytes32 messageHash, address from, address to);

    constructor(address[] memory _authorizedRelayers) public {
        authorizedRelayers = _authorizedRelayers;
        for (uint i = 0; i < authorizedRelayers.length; i++) {
            isRelayer[authorizedRelayers[i]] = true;
        }
    }

    function forwardMessage(bytes calldata message) external {
        bytes32 messageHash = keccak256(message);
        require(!processedMessages[messageHash], "Message already processed");
        require(isRelayer[msg.sender], "Not authorized relayer");
        emit MessageForwarded(messageHash, msg.sender, address(this));
        processedMessages[messageHash] = true;
    }
}