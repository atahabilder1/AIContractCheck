// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AutoCompoundingVault {
    IUniswapV2Pair public uniswapV2Pair;
    address private token0;
    address private token1;

    constructor(address _pairAddress) {
        uniswapV2Pair = IUniswapV2Pair(_pairAddress);
        (token0, token1) = uniswapV2Pair.token0(), uniswapV2Pair.token1();
    }

    function compoundRewards() external {
        uint liquidity = uniswapV2Pair.balanceOf(address(this));
        if (liquidity == 0) return;

        IERC20 tokenInstance0 = IERC20(token0);
        IERC20 tokenInstance1 = IERC20(token1);

        uint256 amountToken0 = tokenInstance0.balanceOf(address(this));
        uint256 amountToken1 = tokenInstance1.balanceOf(address(this));

        uniswapV2Pair.swap(amountToken0, 0, address(token0), this);
        uniswapV2Pair.swap(amountToken1, 0, address(token1), this);
    }
}