// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ConcentratedLiquidityDEX {
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 fee; // fee in basis points
        uint160 sqrtPriceX96;
    }

    struct Position {
        uint128 liquidity;
        uint256 token0Amount;
        uint256 token1Amount;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(address => mapping(bytes32 => Position)) public positions;

    event PoolCreated(address indexed token0, address indexed token1, uint256 fee, uint160 sqrtPriceX96);
    event Swap(address indexed sender, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed sender, bytes32 indexed poolId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(address indexed sender, bytes32 indexed poolId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function createPool(address _token0, address _token1, uint256 _fee, uint160 _sqrtPriceX96) external {
        require(_token0 < _token1, "TOKENS");
        bytes32 poolId = keccak256(abi.encode(_token0, _token1, _fee));
        require(pools[poolId].token0 == address(0), "POOL_EXISTS");
        pools[poolId] = Pool({token0: _token0, token1: _token1, fee: _fee, reserve0: 0, reserve1: 0, sqrtPriceX96: _sqrtPriceX96});
        emit PoolCreated(_token0, _token1, _fee, _sqrtPriceX96);
    }

    function addLiquidity(bytes32 _poolId, uint128 _liquidity, uint256 _amount0, uint256 _amount1) external {
        Pool storage pool = pools[_poolId];
        require(pool.token0 != address(0), "POOL_NOT_FOUND");
        positions[msg.sender][_poolId].liquidity += _liquidity;
        positions[msg.sender][_poolId].token0Amount += _amount0;
        positions[msg.sender][_poolId].token1Amount += _amount1;
        pool.reserve0 += _amount0;
        pool.reserve1 += _amount1;
        IERC20(pool.token0).transferFrom(msg.sender, address(this), _amount0);
        IERC20(pool.token1).transferFrom(msg.sender, address(this), _amount1);
        emit LiquidityAdded(msg.sender, _poolId, _liquidity, _amount0, _amount1);
    }

    function removeLiquidity(bytes32 _poolId, uint128 _liquidity, uint256 _minAmount0, uint256 _minAmount1) external {
        Pool storage pool = pools[_poolId];
        require(pool.token0 != address(0), "POOL_NOT_FOUND");
        require(positions[msg.sender][_poolId].liquidity >= _liquidity, "LIQUIDITY");
        (uint256 amount0, uint256 amount1) = getAmountsForLiquidity(_poolId, _liquidity);
        require(amount0 >= _minAmount0 && amount1 >= _minAmount1, "SLIPPAGE");
        positions[msg.sender][_poolId].liquidity -= _liquidity;
        positions[msg.sender][_poolId].token0Amount -= amount0;
        positions[msg.sender][_poolId].token1Amount -= amount1;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        IERC20(pool.token0).transfer(msg.sender, amount0);
        IERC20(pool.token1).transfer(msg.sender, amount1);
        emit LiquidityRemoved(msg.sender, _poolId, _liquidity, amount0, amount1);
    }

    function swap(bytes32 _poolId, address _tokenIn, uint256 _amountIn, uint256 _minAmountOut) external {
        Pool storage pool = pools[_poolId];
        require(pool.token0 != address(0), "POOL_NOT_FOUND");
        require(_tokenIn == pool.token0 || _tokenIn == pool.token1, "TOKEN");
        bool zeroForOne = _tokenIn == pool.token0;
        (uint256 amountIn, uint256 amountOut) = zeroForOne ? swapExact0For1(pool, _amountIn) : swapExact1For0(pool, _amountIn);
        require(amountOut >= _minAmountOut, "SLIPPAGE");
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(zeroForOne ? pool.token1 : pool.token0).transfer(msg.sender, amountOut);
        emit Swap(msg.sender, _tokenIn, zeroForOne ? pool.token1 : pool.token0, amountIn, amountOut);
    }

    function getAmountsForLiquidity(bytes32 _poolId, uint128 _liquidity) public view returns (uint256 amount0, uint256 amount1) {
        Pool storage pool = pools[_poolId];
        uint256 balance0 = IERC20(pool.token0).balanceOf(address(this));
        uint256 balance1 = IERC20(pool.token1).balanceOf(address(this));
        amount0 = _liquidity * balance0 / positions[msg.sender][_poolId].liquidity;
        amount1 = _liquidity * balance1 / positions[msg.sender][_poolId].liquidity;
    }

    function swapExact0For1(Pool storage pool, uint256 amountIn) internal returns (uint256 amountIn_, uint256 amountOut) {
        amountIn_ = amountIn * (10000 - pool.fee) / 10000;
        pool.reserve0 += amountIn_;
        amountOut = pool.reserve1 - (pool.reserve0 * pool.reserve1) / (pool.reserve0 + amountIn_);
        pool.reserve1 -= amountOut;
        pool.sqrtPriceX96 = getNewSqrtPrice(pool.sqrtPriceX96, pool.reserve0, pool.reserve1);
    }

    function swapExact1For0(Pool storage pool, uint256 amountIn) internal returns (uint256 amountIn_, uint256 amountOut) {
        amountIn_ = amountIn * (10000 - pool.fee) / 10000;
        pool.reserve1 += amountIn_;
        amountOut = pool.reserve0 - (pool.reserve0 * pool.reserve1) / (pool.reserve1 + amountIn_);
        pool.reserve0 -= amountOut;
        pool.sqrtPriceX96 = getNewSqrtPrice(pool.sqrtPriceX96, pool.reserve0, pool.reserve1);
    }

    function getNewSqrtPrice(uint160 sqrtPriceX96, uint256 reserve0, uint256 reserve1) internal pure returns (uint160) {
        return uint160(sqrt(reserve0 * reserve1) * 2 ** 96 / (reserve0 + reserve1));
    }

    function sqrt(uint x) internal pure returns (uint y) {
        y = x;
        uint z = x / 2 + 1;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}