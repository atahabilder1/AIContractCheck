// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrossChainMessaging {
    IERC20 private _sourceToken;
    address payable public recipient;

    constructor(address sourceTokenAddress, address initialRecipient) {
        _sourceToken = IERC20(sourceTokenAddress);
        recipient = payable(initialRecipient);
    }

    function transferTokens(uint256 amount) external returns (bool success) {
        require(_sourceToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        _sourceToken.approve(address(0), amount); // Revoke approval to avoid replay attacks
        recipient.transfer(amount);
        return true;
    }
}