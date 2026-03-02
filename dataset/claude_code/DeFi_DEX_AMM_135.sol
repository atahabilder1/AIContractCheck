// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic DEX/AMM Contract
contract BasicAMM {
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalLiquidity;

    mapping(address => uint256) public liquidity;

    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);
    event AddLiquidity(address indexed user, uint256 amount0, uint256 amount1, uint256 liquidity);
    event RemoveLiquidity(address indexed user, uint256 amount0, uint256 amount1, uint256 liquidity);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liq) {
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        if (totalLiquidity == 0) {
            liq = sqrt(amount0 * amount1);
        } else {
            liq = min(amount0 * totalLiquidity / reserve0, amount1 * totalLiquidity / reserve1);
        }

        require(liq > 0, "Insufficient liquidity minted");
        liquidity[msg.sender] += liq;
        totalLiquidity += liq;
        reserve0 += amount0;
        reserve1 += amount1;

        emit AddLiquidity(msg.sender, amount0, amount1, liq);
    }

    function removeLiquidity(uint256 liq) external returns (uint256 amount0, uint256 amount1) {
        require(liquidity[msg.sender] >= liq, "Insufficient liquidity");

        amount0 = liq * reserve0 / totalLiquidity;
        amount1 = liq * reserve1 / totalLiquidity;

        liquidity[msg.sender] -= liq;
        totalLiquidity -= liq;
        reserve0 -= amount0;
        reserve1 -= amount1;

        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        emit RemoveLiquidity(msg.sender, amount0, amount1, liq);
    }

    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        require(tokenIn == token0 || tokenIn == token1, "Invalid token");

        bool isToken0 = tokenIn == token0;
        (uint256 resIn, uint256 resOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // x * y = k, with 0.3% fee
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * resOut) / (resIn * 1000 + amountInWithFee);

        if (isToken0) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
            IERC20(token1).transfer(msg.sender, amountOut);
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
            IERC20(token0).transfer(msg.sender, amountOut);
        }

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(address tokenIn, uint256 amountIn) public view returns (uint256) {
        bool isToken0 = tokenIn == token0;
        (uint256 resIn, uint256 resOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * resOut) / (resIn * 1000 + amountInWithFee);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) { z = x; x = (y / x + x) / 2; }
        } else if (y != 0) { z = 1; }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) { return a < b ? a : b; }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
