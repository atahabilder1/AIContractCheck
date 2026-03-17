// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public tokenContractAddress; // Address of the ERC20 token on source chain
    IERC20 token = IERC20(tokenContractAddress);

    constructor(address _tokenContractAddress) {
        tokenContractAddress = _tokenContractAddress;
    }

    function relayTokens(address recipient, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Emit an event for the destination chain to pick up and mint tokens
        emit TokensRelayed(recipient, amount);
    }

    interface IERC20 {
        function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    }

    event TokensRelayed(address indexed recipient, uint256 amount);
}