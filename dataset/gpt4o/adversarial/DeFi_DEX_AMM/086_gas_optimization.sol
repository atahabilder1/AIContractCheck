// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OptimizedDEX {
    address public token0;
    address public token1;
    uint256 private reserve0;
    uint256 private reserve1;
    uint256 private totalSupply;
    mapping(address => uint256) private balances;

    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, address indexed to);
    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x < y ? x : y;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liquidity) {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1);
        } else {
            liquidity = _min(amount0 * _totalSupply / reserve0, amount1 * _totalSupply / reserve1);
        }
        require(liquidity > 0, "Insufficient liquidity");
        balances[msg.sender] += liquidity;
        totalSupply += liquidity;
        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity);
        _update(reserve0 + amount0, reserve1 + amount1);
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amount0, uint256 amount1) {
        uint256 balance = balances[msg.sender];
        require(balance >= liquidity, "Not enough liquidity");
        balances[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        amount0 = liquidity * reserve0 / totalSupply;
        amount1 = liquidity * reserve1 / totalSupply;
        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
        _update(reserve0 - amount0, reserve1 - amount1);
    }

    function swap(uint256 amountIn, address to, bool zeroForOne) external returns (uint256 amountOut) {
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        require(amountIn > 0, "Insufficient input amount");
        if (zeroForOne) {
            amountOut = amountIn * _reserve1 / (_reserve0 + amountIn);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            amountOut = amountIn * _reserve0 / (_reserve1 + amountIn);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }
        require(amountOut > 0, "Insufficient output amount");
        emit Swap(msg.sender, amountIn, amountOut, to);
    }

    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }
}