// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ConstantProductAMM {
    uint256 public constant k = 100; // The constant product (k)
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(uint256 _reserve0, uint256 _reserve1) {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) public {
        require(amount0 * amount1 / k == 0, "Invalid liquidity adding amount");
        reserve0 += amount0;
        reserve1 += amount1;
    }

    function removeLiquidity(uint256 liquidity) public {
        require(liquidity * k / reserve0 > 0 && liquidity * k / reserve1 > 0, "Invalid liquidity removing amount");
        uint256 amount0 = (liquidity * reserve0) / k;
        uint256 amount1 = (liquidity * reserve1) / k;
        reserve0 -= amount0;
        reserve1 -= amount1;
    }

    function swap(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256 outputAmount) {
        require(inputAmount > 0 && inputReserve > 0 && outputReserve > 0, "Invalid input amount or reserves");
        uint256 inputAmountWithFee = inputAmount * 997; // 99.7% of the input amount
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve * 1000 + inputAmountWithFee;
        outputAmount = numerator / denominator;
    }
}