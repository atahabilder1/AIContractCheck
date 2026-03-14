// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AutoCompoundingVault is Ownable {
    IUniswapV2Router02 public immutable uniswapRouter;
    IUniswapV2Pair public immutable lpPair;
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    constructor(
        address _router,
        address _lpPair
    ) {
        uniswapRouter = IUniswapV2Router02(_router);
        lpPair = IUniswapV2Pair(_lpPair);
        (address token0, address token1) = (lpPair.token0(), lpPair.token1());
        tokenA = IERC20(token0);
        tokenB = IERC20(token1);

        tokenA.approve(_router, type(uint256).max);
        tokenB.approve(_router, type(uint256).max);
        lpPair.approve(_router, type(uint256).max);
    }

    function compound() external {
        uint256 rewards = lpPair.balanceOf(address(this));
        if (rewards == 0) return;

        lpPair.transfer(address(uniswapRouter), rewards);
        uniswapRouter.removeLiquidity(
            address(tokenA),
            address(tokenB),
            rewards,
            0,
            0,
            address(this),
            block.timestamp
        );

        uint256 halfA = tokenA.balanceOf(address(this)) / 2;
        uint256 halfB = tokenB.balanceOf(address(this)) / 2;

        address[] memory pathA = new address[](2);
        pathA[0] = address(tokenA);
        pathA[1] = address(tokenB);
        uniswapRouter.swapExactTokensForTokens(
            halfA,
            0,
            pathA,
            address(this),
            block.timestamp
        );

        address[] memory pathB = new address[](2);
        pathB[0] = address(tokenB);
        pathB[1] = address(tokenA);
        uniswapRouter.swapExactTokensForTokens(
            halfB,
            0,
            pathB,
            address(this),
            block.timestamp
        );

        uint256 amountA = tokenA.balanceOf(address(this));
        uint256 amountB = tokenB.balanceOf(address(this));

        uniswapRouter.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function withdraw() external onlyOwner {
        uint256 balance = lpPair.balanceOf(address(this));
        if (balance > 0) {
            lpPair.transfer(msg.sender, balance);
        }
    }
}