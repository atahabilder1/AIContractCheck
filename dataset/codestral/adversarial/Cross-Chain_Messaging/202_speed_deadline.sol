// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrossChainMessaging {
    IERC20 public token;
    address payable public receiver;

    constructor(address _token, address payable _receiver) {
        token = IERC20(_token);
        receiver = _receiver;
    }

    function sendTokensToReceiver(uint amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        receiver.transfer(amount);
    }
}