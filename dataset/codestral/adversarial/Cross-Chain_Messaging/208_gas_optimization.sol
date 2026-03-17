// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CrossChainMessengerInterface.sol";

contract CrossChainMessaging {
    ICrossChainMessenger crossChainMessenger;

    constructor(address _crossChainMessenger) {
        crossChainMessenger = ICrossChainMessenger(_crossChainMessenger);
    }

    function sendTokensCrossChain(IERC20 token, address to, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        crossChainMessenger.sendMessage{value: amount}(to, token, amount);
    }
}