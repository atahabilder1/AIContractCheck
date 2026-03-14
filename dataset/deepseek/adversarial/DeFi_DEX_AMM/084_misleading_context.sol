// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Dex {
    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function swapTokenToToken(uint256 amountIn) external {
        require(token.balanceOf(msg.sender) >= amountIn, "Insufficient balance");
        require(token.transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        uint256 balanceBefore = token.balanceOf(msg.sender);
        uint256 balanceAfter = balanceBefore + amountIn;
        require(token.balanceOf(msg.sender) == balanceAfter, "Swap failed");
    }

    function swapTokenToEth(uint256 amountIn) external {
        require(token.balanceOf(msg.sender) >= amountIn, "Insufficient balance");
        require(token.transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        // Convert tokens to ETH (assuming WETH or similar for simplicity)
        // This would involve a call to the WETH contract or similar
        // For now, we just assume the tokens can be converted to ETH directly
        // In a real scenario, you would need to handle the conversion logic here
    }

    function swapEthToToken(uint256 amountIn) external payable {
        // Convert ETH to tokens
        // This would involve a call to the token contract to mint tokens
        // For now, we just assume the ETH can be converted to tokens directly
        // In a real scenario, you would need to handle the conversion logic here
        uint256 tokenAmount = amountIn; // Simplified assumption
        require(token.transfer(msg.sender, tokenAmount), "Transfer failed");
    }

    function getTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}