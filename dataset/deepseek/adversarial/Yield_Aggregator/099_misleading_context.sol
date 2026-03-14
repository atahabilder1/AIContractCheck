// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract YieldAggregator {
    IUniswapV2Router public immutable uniswapV2Router;
    address public immutable WETH;

    constructor(address _uniswapV2Router, address _WETH) {
        uniswapV2Router = IUniswapV2Router(_uniswapV2Router);
        WETH = _WETH;
    }

    function swapTokensForEth(address token, uint256 amount) external {
        require(IERC20(token).balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(IERC20(token).allowance(msg.sender, address(this)) >= amount, "Allowance too low");

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH;

        IERC20(token).approve(address(uniswapV2Router), amount);
        uniswapV2Router.swapExactTokensForTokens(amount, 0, path, msg.sender, block.timestamp);
    }
}