// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TokenBridge {
    event TokenMinted(address indexed token, address indexed recipient, uint256 amount);

    function lockToken(address token, uint256 amount) public {
        // Lock the token on this chain
        require(token.transfer(amount), "Token transfer failed");

        // Emit an event for minting the token on the other chain
        emit TokenMinted(token, msg.sender, amount);
    }
}