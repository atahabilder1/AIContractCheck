// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ConcentratedLiquidityDex {
    using SafeMath for uint256;

    IERC20 public token0;
    IERC20 public token1;
    uint256 public feePercentage;

    struct LiquidityPool {
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
    }

    mapping(address => LiquidityPool) public liquidityPools;

    event LiquidityAdded(address indexed lp, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(address indexed lp, uint256 amount0, uint256 amount1);
    event Swap(address indexed trader, uint256 amountIn, uint256 amountOut, uint256 fee);

    constructor(address _token0, address _token1, uint256 _feePercentage) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feePercentage = _feePercentage;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external {
        require(amount0 > 0 && amount1 > 0, "Amounts must be greater than zero");
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        LiquidityPool storage pool = liquidityPools[msg.sender];
        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalSupply += getLiquidity(amount0, amount1);
        pool.balanceOf[msg.sender] += getLiquidity(amount0, amount1);

        emit LiquidityAdded(msg.sender, amount0, amount1);
    }

    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Liquidity must be greater than zero");
        LiquidityPool storage pool = liquidityPools[msg.sender];
        require(pool.balanceOf[msg.sender] >= liquidity, "Insufficient liquidity");

        uint256 amount0 = (liquidity * pool.reserve0) / pool.totalSupply;
        uint256 amount1 = (liquidity * pool.reserve1) / pool.totalSupply;

        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalSupply -= liquidity;
        pool.balanceOf[msg.sender] -= liquidity;

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1);
    }

    function swap(uint256 amountIn, uint256 minAmountOut, address recipient) external {
        require(amountIn > 0, "AmountIn must be greater than zero");
        require(minAmountOut > 0, "MinAmountOut must be greater than zero");

        LiquidityPool storage pool = liquidityPools[recipient];
        uint256 amountOut = getAmountOut(amountIn, pool.reserve0, pool.reserve1);
        require(amountOut >= minAmountOut, "Slippage protection: amountOut is less than minAmountOut");

        uint256 fee = (amountIn * feePercentage) / 100;
        uint256 amountInWithFee = amountIn + fee;

        token0.transferFrom(msg.sender, address(this), amountInWithFee);
        token1.transfer(msg.sender, amountOut);

        pool.reserve0 += amountInWithFee;
        pool.reserve1 -= amountOut;

        emit Swap(msg.sender, amountIn, amountOut, fee);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        require(amountIn > 0, "AmountIn must be greater than zero");
        require(reserveIn > 0 && reserveOut > 0, "Reserves must be greater than zero");

        uint256 amountInWithFee = amountIn * (100 - feePercentage);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;

        return (numerator / denominator);
    }

    function getLiquidity(uint256 amount0, uint256 amount1) internal pure returns (uint256) {
        return sqrt(amount0 * amount1);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
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
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}