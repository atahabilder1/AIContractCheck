```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract ConcentratedLiquidityDEX is Ownable {
    struct Pool {
        address tokenA;
        address tokenB;
        uint256 feeTier; // In basis points, e.g., 30 for 0.30%
        uint256 tickSpacing;
        mapping(int24 => Tick) ticks;
        mapping(int24 => Liquidity) liquidity;
        uint256 sqrtPriceX96;
        int24 currentTick;
        uint256 liquidityGlobal;
    }

    struct Tick {
        uint256 liquidityNet; // Change in liquidity at this tick
        uint256 liquidityGross; // Total liquidity provided at this tick
        uint256 feeGrowthOutside; // Fee growth accumulated outside this tick
    }

    struct Liquidity {
        uint256 liquidityGross;
        uint256 feeGrowthTokenA;
        uint256 feeGrowthTokenB;
    }

    // Mapping of pair hash to pool
    mapping(bytes32 => Pool) public pools;
    // Mapping of pool to fee tier and tick spacing
    mapping(address => mapping(address => mapping(uint256 => Pool))) public poolData;

    // Fee collected by LPs
    uint256 public constant FEE_DENOMINATOR = 1e18; // 100%

    // Maximum tick value
    int24 public constant MAX_TICK = 887272;
    // Minimum tick value
    int24 public constant MIN_TICK = -887272;

    // Event for adding liquidity
    event AddLiquidity(
        address indexed tokenA,
        address indexed tokenB,
        uint256 feeTier,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 feeGrowthTokenA,
        uint256 feeGrowthTokenB
    );

    // Event for removing liquidity
    event RemoveLiquidity(
        address indexed tokenA,
        address indexed tokenB,
        uint256 feeTier,
        int256 tickLower,
        int256 tickUpper,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 feeGrowthTokenA,
        uint256 feeGrowthTokenB
    );

    // Event for swapping tokens
    event Swap(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 feeTier,
        uint256 amountIn,
        uint256 amountOut,
        uint256 sqrtPriceX96,
        int256 tick
    );

    // Helper function to get the pool for a given pair of tokens and fee tier
    function getPool(address tokenA, address tokenB, uint256 feeTier) internal view returns (Pool storage pool) {
        bytes32 pairHash = keccak256(abi.encodePacked(tokenA, tokenB, feeTier));
        return pools[pairHash];
    }

    // Function to create a new pool
    function createPool(address tokenA, address tokenB, uint256 feeTier, uint256 tickSpacing) public onlyOwner {
        // Ensure tokens are valid and different
        require(tokenA != address(0) && tokenB != address(0), "Invalid tokens");
        require(tokenA != tokenB, "Tokens must be different");

        // Order tokens to ensure consistent pool creation
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        bytes32 pairHash = keccak256(abi.encodePacked(tokenA, tokenB, feeTier));
        require(pools[pairHash].tokenA == address(0), "Pool already exists");

        Pool storage newPool = pools[pairHash];
        newPool.tokenA = tokenA;
        newPool.tokenB = tokenB;
        newPool.feeTier = feeTier;
        newPool.tickSpacing = tickSpacing;
        newPool.sqrtPriceX96 = 79228162514264337593543950336; // 1e18
        newPool.currentTick = 0;
        newPool.liquidityGlobal = 0;
    }

    // Function to add liquidity
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeTier,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountA,
        uint256 amountB,
        uint256 minAmountA, // For slippage protection
        uint256 minAmountB  // For slippage protection
    ) external returns (uint256 liquidity, uint256 amountAOut, uint256 amountBOut) {
        Pool storage pool = getPool(tokenA, tokenB, feeTier);
        require(pool.tokenA != address(0), "Pool does not exist");

        // Ensure tick bounds are valid
        require(tickLower < tickUpper, "Invalid tick bounds");
        require(tickLower >= MIN_TICK && tickUpper <= MAX_TICK, "Ticks out of bounds");

        // Ensure tick bounds are multiples of tickSpacing
        require(tickLower % int256(pool.tickSpacing) == 0, "Lower tick not aligned");
        require(tickUpper % int256(pool.tickSpacing) == 0, "Upper tick not aligned");

        // Transfer tokens from user to the contract
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        (liquidity, amountAOut, amountBOut) = _addLiquidity(
            pool,
            msg.sender,
            tickLower,
            tickUpper,
            amountA,
            amountB
        );

        // Check for slippage
        require(amountAOut >= minAmountA, "Slippage detected (Amount A)");
        require(amountBOut >= minAmountB, "Slippage detected (Amount B)");

        emit AddLiquidity(
            tokenA,
            tokenB,
            feeTier,
            tickLower,
            tickUpper,
            amountAOut,
            amountBOut,
            liquidity,
            pool.ticks[tickLower].feeGrowthTokenA, // This should be updated within _addLiquidity
            pool.ticks[tickLower].feeGrowthTokenB  // This should be updated within _addLiquidity
        );
    }

    function _addLiquidity(
        Pool storage pool,
        address to,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 liquidity, uint256 amountAUsed, uint256 amountBUsed) {
        int24 currentTick = pool.currentTick;
        uint128 sqrtPriceX96 = uint128(pool.sqrtPriceX96);

        // Calculate liquidity if current tick is within the range
        if (currentTick >= tickLower && currentTick < tickUpper) {
            uint128 price = uint128(sqrtPriceX96);
            uint256 amountTokenAForLiquidity = (uint256(price) * uint256(price)) >> 192; // price^2
            uint256 amountTokenBForLiquidity = (uint256(price) << 96) >> 96; // price

            if (amountA == 0 && amountB == 0) {
                // Claim fees
                uint256 feeGrowthTokenA = pool.ticks[tickLower].feeGrowthTokenA;
                uint256 feeGrowthTokenB = pool.ticks[tickLower].feeGrowthTokenB;
                // ... calculate and distribute fees to sender ...
                return (0, 0, 0);
            }

            if (pool.liquidityGlobal == 0) {
                liquidity = Math.min(
                    (amountA * (1 << 96)) / amountTokenAForLiquidity,
                    (amountB * (1 << 96)) / amountTokenBForLiquidity
                );
            } else {
                liquidity = Math.min(
                    (amountA * (1 << 96)) / amountTokenAForLiquidity,
                    (amountB * (1 << 96)) / amountTokenBForLiquidity
                );
                liquidity = Math.min(liquidity, pool.liquidityGlobal);
            }
        } else {
            liquidity = Math.min(
                (amountA * (1 << 96)) / getAmountTokenAForLiquidity(sqrtPriceX96, tickLower),
                (amountB * (1 << 96)) / getAmountTokenBForLiquidity(sqrtPriceX96, tickUpper)
            );
        }

        _updateLiquidity(pool, tickLower, tickUpper, liquidity, amountA, amountB, true);

        return (liquidity, amountA, amountB); // This needs to be precise amounts used
    }

    // Function to remove liquidity
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeTier,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint256 minAmountA, // For slippage protection
        uint256 minAmountB  // For slippage protection
    ) external returns (uint256 amountA, uint256 amountB) {
        Pool storage pool = getPool(tokenA, tokenB, feeTier);
        require(pool.tokenA != address(0), "Pool does not exist");

        require(tickLower < tickUpper, "Invalid tick bounds");
        require(tickLower >= MIN_TICK && tickUpper <= MAX_TICK, "Ticks out of bounds");
        require(tickLower % int256(pool.tickSpacing) == 0, "Lower tick not aligned");
        require(tickUpper % int256(pool.tickSpacing) == 0, "Upper tick not aligned");

        (amountA, amountB) = _removeLiquidity(
            pool,
            msg.sender,
            tickLower,
            tickUpper,
            liquidity
        );

        require(amountA >= minAmountA, "Slippage detected (Amount A)");
        require(amountB >= minAmountB, "Slippage detected (Amount B)");

        // Transfer tokens back to user
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit RemoveLiquidity(
            tokenA,
            tokenB,
            feeTier,
            tickLower,
            tickUpper,
            amountA,
            amountB,
            liquidity,
            pool.ticks[tickLower].feeGrowthTokenA, // This should be updated within _removeLiquidity
            pool.ticks[tickLower].feeGrowthTokenB  // This should be updated within _removeLiquidity
        );
    }

    function _removeLiquidity(
        Pool storage pool,
        address to,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity
    ) internal returns (uint256 amountA, uint256 amountB) {
        uint128 sqrtPriceX96 = uint128(pool.sqrtPriceX96);

        amountA = getAmountAForLiquidity(sqrtPriceX96, tickLower, tickUpper);
        amountB = getAmountBForLiquidity(sqrtPriceX96, tickLower, tickUpper);

        _updateLiquidity(pool, tickLower, tickUpper, liquidity, 0, 0, false);

        return (amountA, amountB);
    }

    // Function to swap tokens
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 feeTier,
        uint256 amountIn,
        uint256 minAmountOut // For slippage protection
    ) external returns (uint256 amountOut) {
        Pool storage pool = getPool(tokenIn, tokenOut, feeTier);
        require(pool.tokenA != address(0), "Pool does not exist");

        require(amountIn > 0, "Amount in must be positive");

        // Transfer tokens from user to the contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        (amountOut, pool.sqrtPriceX96, pool.currentTick) = _swap(
            pool,
            amountIn,
            0 // Amount out is calculated
        );

        // Check for slippage
        require(amountOut >= minAmountOut, "Slippage detected");

        // Transfer tokens to user
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swap(
            tokenIn,
            tokenOut,
            feeTier,
            amountIn,
            amountOut,
            pool.sqrtPriceX96,
            pool.currentTick
        );
    }

    function _swap(
        Pool storage pool,
        uint256 amountIn,
        uint256 amountOut // If pre-determined
    ) internal returns (uint256 amountOutActual, uint128 newSqrtPriceX96, int24 newCurrentTick) {
        uint128 sqrtPriceX96 = uint128(pool.sqrtPriceX96);
        int24 currentTick = pool.currentTick;
        uint256 fee = (amountIn * pool.feeTier) / (10000 * 100); // 0.30% fee
        uint256 amountToSwap = amountIn - fee;

        // Determine if swapping tokenA for tokenB or tokenB for tokenA
        bool zeroForOne = pool.tokenA == msg.sender; // Assuming msg.sender is the token being swapped FROM

        if (zeroForOne) {
            // Swapping tokenA for tokenB
            while (amountToSwap > 0 && currentTick < MAX_TICK) {
                int24 nextTick = getNextTick(currentTick, pool.tickSpacing);
                uint128 nextSqrtPriceX96 = getSqrtPriceX96(nextTick);
                uint256 amountAToSpend = amountToSwap;
                uint256 maxAmountAInPool = getAmountAForLiquidity(sqrtPriceX96, currentTick, nextTick);

                if (amountAToSpend > maxAmountAInPool) {
                    amountAToSpend = maxAmountAInPool;
                }

                uint256 amountBReceived = getAmountBForSwap(sqrtPriceX96, nextSqrtPriceX96, amountAToSpend);

                amountToSwap -= amountAToSpend;
                amountToSwap = amountToSwap; // Update amountToSwap

                pool.sqrtPriceX96 = nextSqrtPriceX96;
                currentTick = nextTick;
                amountOutActual += amountBReceived;

                if (amountToSwap > 0) {
                    // Need to cross a tick, update liquidity and potentially continue
                }
            }
        } else {
            // Swapping tokenB for tokenA
            while (amountToSwap > 0 && currentTick > MIN_TICK) {
                int24 prevTick = getPrevTick(currentTick, pool.tickSpacing);
                uint128 prevSqrtPriceX96 = getSqrtPriceX96(prevTick);
                uint256 amountBToSpend = amountToSwap;
                uint256 maxAmountBInPool = getAmountBForLiquidity(sqrtPriceX96, prevTick, currentTick);

                if (amountBToSpend > maxAmountBInPool) {
                    amountBToSpend = maxAmountBInPool;
                }

                uint256 amountAReceived = getAmountAForSwap(sqrtPriceX96, prevSqrtPriceX96, amountBToSpend);

                amountToSwap -= amountBToSpend;
                amountToSwap = amountToSwap; // Update amountToSwap

                pool.sqrtPriceX96 = prevSqrtPriceX96;
                currentTick = prevTick;
                amountOutActual += amountAReceived;

                if (amountToSwap > 0) {
                    // Need to cross a tick, update liquidity and potentially continue
                }
            }
        }

        newSqrtPriceX96 = uint128(pool.sqrtPrice