// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeRelayer {
    IERC20 public sourceToken;
    IERC20 public destinationToken;

    constructor(address _sourceToken, address _destinationToken) {
        sourceToken = IERC20(_sourceToken);
        destinationToken = IERC20(_destinationToken);
    }

    function relayTokens(uint256 amount, address recipient) external {
        require(sourceToken.transferFrom(msg.sender, address(this), amount), "Transfer failed.");
        destinationToken.transfer(recipient, amount);
    }
}