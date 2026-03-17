// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TokenBridge {
    event TokensLocked(address indexed sender, uint256 amount);
    event TokensMinted(address indexed recipient, uint256 amount);

    IERC20 public token;

    constructor(IERC20 _token) {
        token = _token;
    }

    function lockTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero.");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed.");
        emit TokensLocked(msg.sender, amount);
    }

    function mintTokensOnOtherChain(address recipient, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero.");
        emit TokensMinted(recipient, amount);
    }
}