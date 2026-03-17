// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public tokenContract;
    address public targetChainAddress;

    constructor(address _tokenContract, address _targetChainAddress) {
        tokenContract = _tokenContract;
        targetChainAddress = _targetChainAddress;
    }

    function depositTokens(uint256 amount) external {
        IERC20 token = IERC20(tokenContract);
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        // Add code to send tokens to targetChainAddress on the other chain
    }

    interface IERC20 {
        function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    }
}