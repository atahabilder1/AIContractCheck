// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
}

contract YieldAggregator {
    address public owner;
    IUniswapV2Router public uniswapRouter;

    constructor(address _uniswapRouter) {
        owner = msg.sender;
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
    }

    function swapTokens(address tokenIn, address tokenOut, uint amountIn) external {
        require(msg.sender == owner, "Only owner can call this function");
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        uint deadline = block.timestamp + 3600; // 1 hour
        uniswapRouter.swapExactTokensForTokens(amountIn, 0, path, address(this), deadline);
    }

    function approveToken(address token, address spender, uint amount) external {
        require(msg.sender == owner, "Only owner can call this function");
        IERC20(token).approve(spender, amount);
    }
}