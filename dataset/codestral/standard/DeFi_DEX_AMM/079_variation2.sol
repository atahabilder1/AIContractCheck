// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Amm {
    uint256 public constant LINEAR_PRICE = 1;
    uint256 public constant EXPONENTIAL_PRICE = 2;

    uint256 private reserveX;
    uint256 private reserveY;

    constructor(uint256 _initialReserveX, uint256 _initialReserveY) {
        require(_initialReserveX > 0 && _initialReserveY > 0, "Initial reserves must be greater than zero");
        reserveX = _initialReserveX;
        reserveY = _initialReserveY;
    }

    function swap(uint256 amountIn, uint256 minAmountOut, uint256 priceDiscovery) public returns (uint256 amountOut) {
        require(priceDiscovery == LINEAR_PRICE || priceDiscovery == EXPONENTIAL_PRICE, "Invalid price discovery method");

        if (priceDiscovery == LINEAR_PRICE) {
            amountOut = linearSwap(amountIn);
        } else {
            amountOut = exponentialSwap(amountIn);
        }

        require(amountOut >= minAmountOut, "Insufficient output amount");
    }

    function linearSwap(uint256 amountIn) private returns (uint256 amountOut) {
        uint256 newReserveX = reserveX + amountIn;
        uint256 price = reserveY / reserveX;
        amountOut = amountIn * price;
        reserveX = newReserveX;
        reserveY -= amountOut;
    }

    function exponentialSwap(uint256 amountIn) private returns (uint256 amountOut) {
        uint256 newReserveX = reserveX + amountIn;
        uint256 price = reserveY * reserveY / reserveX;
        amountOut = amountIn * price;
        reserveX = newReserveX;
        reserveY -= amountOut;
    }
}