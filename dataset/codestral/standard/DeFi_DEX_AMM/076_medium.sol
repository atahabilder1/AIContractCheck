// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TickMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConcentratedLiquityDEX {
    ISwapRouter private immutable swapRouter;
    address public immutable factory;

    constructor(address _swapRouter, address _factory) {
        swapRouter = ISwapRouter(_swapRouter);
        factory = _factory;
    }

    struct SwapParams {
        IERC20 tokenIn;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        address recipient;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
    }

    function swapExactInput(SwapParams memory params) external returns (uint256 amountOut) {
        bytes memory path = abi.encodePacked(params.tokenIn, factory, params.fee);
        IERC20(params.tokenIn).approve(address(swapRouter), params.amountIn);
        uint160 sqrtPriceLimitX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);
        amountOut = swapRouter.exactInputSingle{value: params.amountIn}(SwapParams({
            tokenIn: params.tokenIn,
            recipient: params.recipient,
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.minAmountOut,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        }), path);
    }
}