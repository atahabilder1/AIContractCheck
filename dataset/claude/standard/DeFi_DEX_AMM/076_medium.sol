// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract ConcentratedLiquidityDEX is ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Pool {
        address token0;
        address token1;
        uint24 fee;
        uint160 sqrtPriceX96;
        int24 currentTick;
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        bool initialized;
    }

    struct Position {
        bytes32 poolId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct TickInfo {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        bool initialized;
    }

    int24 public constant TICK_SPACING = 60;
    uint256 private constant Q96 = 2 ** 96;
    uint256 private constant Q128 = 2 ** 128;
    int24 public constant MIN_TICK = -887220;
    int24 public constant MAX_TICK = 887220;

    mapping(bytes32 => Pool) public pools;
    mapping(uint256 => Position) public positions;
    mapping(bytes32 => mapping(int24 => TickInfo)) public ticks;

    uint256 private _nextPositionId = 1;

    event PoolCreated(address indexed token0, address indexed token1, uint24 fee, bytes32 poolId);
    event Mint(uint256 indexed positionId, bytes32 indexed poolId, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1);
    event Burn(uint256 indexed positionId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event Swap(bytes32 indexed poolId, address indexed sender, bool zeroForOne, int256 amount0, int256 amount1);
    event CollectFees(uint256 indexed positionId, uint128 amount0, uint128 amount1);

    constructor() ERC721("CL-DEX Position", "CLP") {}

    function getPoolId(address token0, address token1, uint24 fee) public pure returns (bytes32) {
        require(token0 < token1, "Token order");
        return keccak256(abi.encodePacked(token0, token1, fee));
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external returns (bytes32 poolId) {
        require(tokenA != tokenB, "Same token");
        require(fee == 500 || fee == 3000 || fee == 10000, "Invalid fee");
        require(sqrtPriceX96 > 0, "Invalid price");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        poolId = getPoolId(token0, token1, fee);
        require(!pools[poolId].initialized, "Pool exists");

        int24 tick = _getTickAtSqrtPrice(sqrtPriceX96);

        pools[poolId] = Pool({
            token0: token0,
            token1: token1,
            fee: fee,
            sqrtPriceX96: sqrtPriceX96,
            currentTick: tick,
            liquidity: 0,
            feeGrowthGlobal0X128: 0,
            feeGrowthGlobal1X128: 0,
            initialized: true
        });

        emit PoolCreated(token0, token1, fee, poolId);
    }

    function mint(
        bytes32 poolId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityAmount
    ) external nonReentrant returns (uint256 positionId, uint256 amount0, uint256 amount1) {
        Pool storage pool = pools[poolId];
        require(pool.initialized, "Pool not initialized");
        require(tickLower < tickUpper, "tickLower >= tickUpper");
        require(tickLower >= MIN_TICK && tickUpper <= MAX_TICK, "Tick OOB");
        require(tickLower % TICK_SPACING == 0 && tickUpper % TICK_SPACING == 0, "Tick spacing");
        require(liquidityAmount > 0, "Zero liquidity");

        (amount0, amount1) = _calcAmountsForLiquidity(
            pool.sqrtPriceX96,
            _getSqrtPriceAtTick(tickLower),
            _getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        require(amount0 > 0 || amount1 > 0, "Zero amounts");

        _updateTick(poolId, tickLower, liquidityAmount, true, pool.currentTick, pool.feeGrowthGlobal0X128, pool.feeGrowthGlobal1X128);
        _updateTick(poolId, tickUpper, liquidityAmount, false, pool.currentTick, pool.feeGrowthGlobal0X128, pool.feeGrowthGlobal1X128);

        if (pool.currentTick >= tickLower && pool.currentTick < tickUpper) {
            pool.liquidity += liquidityAmount;
        }

        (uint256 feeGrowthInside0, uint256 feeGrowthInside1) = _getFeeGrowthInside(poolId, tickLower, tickUpper);

        positionId = _nextPositionId++;
        positions[positionId] = Position({
            poolId: poolId,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidityAmount,
            feeGrowthInside0LastX128: feeGrowthInside0,
            feeGrowthInside1LastX128: feeGrowthInside1,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        _mint(msg.sender, positionId);

        if (amount0 > 0) IERC20(pool.token0).safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) IERC20(pool.token1).safeTransferFrom(msg.sender, address(this), amount1);

        emit Mint(positionId, poolId, tickLower, tickUpper, liquidityAmount, amount0, amount1);
    }

    function burn(uint256 positionId) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(ownerOf(positionId) == msg.sender, "Not owner");
        Position storage pos = positions[positionId];
        Pool storage pool = pools[pos.poolId];

        uint128 liquidity = pos.liquidity;
        require(liquidity > 0, "No liquidity");

        (amount0, amount1) = _calcAmountsForLiquidity(
            pool.sqrtPriceX96,
            _getSqrtPriceAtTick(pos.tickLower),
            _getSqrtPriceAtTick(pos.tickUpper),
            liquidity
        );

        (uint256 feeGrowthInside0, uint256 feeGrowthInside1) = _getFeeGrowthInside(pos.poolId, pos.tickLower, pos.tickUpper);

        uint128 fees0 = uint128(Math.mulDiv(feeGrowthInside0 - pos.feeGrowthInside0LastX128, liquidity, Q128));
        uint128 fees1 = uint128(Math.mulDiv(feeGrowthInside1 - pos.feeGrowthInside1LastX128, liquidity, Q128));

        _updateTick(pos.poolId, pos.tickLower, liquidity, false, pool.currentTick, pool.feeGrowthGlobal0X128, pool.feeGrowthGlobal1X128);
        _updateTick(pos.poolId, pos.tickUpper, liquidity, true, pool.currentTick, pool.feeGrowthGlobal0X128, pool.feeGrowthGlobal1X128);

        if (pool.currentTick >= pos.tickLower && pool.currentTick < pos.tickUpper) {
            pool.liquidity -= liquidity;
        }

        pos.liquidity = 0;
        pos.feeGrowthInside0LastX128 = feeGrowthInside0;
        pos.feeGrowthInside1LastX128 = feeGrowthInside1;

        uint256 total0 = amount0 + fees0;
        uint256 total1 = amount1 + fees1;

        if (total0 > 0) IERC20(pool.token0).safeTransfer(msg.sender, total0);
        if (total1 > 0) IERC20(pool.token1).safeTransfer(msg.sender, total1);

        emit Burn(positionId, liquidity, amount0, amount1);
        emit CollectFees(positionId, fees0, fees1);
    }

    function collectFees(uint256 positionId) external nonReentrant returns (uint128 amount0, uint128 amount1) {
        require(ownerOf(positionId) == msg.sender, "Not owner");
        Position storage pos = positions[positionId];
        Pool storage pool = pools[pos.poolId];

        (uint256 feeGrowthInside0, uint256 feeGrowthInside1) = _getFeeGrowthInside(pos.poolId, pos.tickLower, pos.tickUpper);

        amount0 = uint128(Math.mulDiv(feeGrowthInside0 - pos.feeGrowthInside0LastX128, pos.liquidity, Q128));
        amount1 = uint128(Math.mulDiv(feeGrowthInside1 - pos.feeGrowthInside1LastX128, pos.liquidity, Q128));

        pos.feeGrowthInside0LastX128 = feeGrowthInside0;
        pos.feeGrowthInside1LastX128 = feeGrowthInside1;

        amount0 += pos.tokensOwed0;
        amount1 += pos.tokensOwed1;
        pos.tokensOwed0 = 0;
        pos.tokensOwed1 = 0;

        if (amount0 > 0) IERC20(pool.token0).safeTransfer(msg.sender, amount0);
        if (amount1 > 0) IERC20(pool.token1).safeTransfer(msg.sender, amount1);

        emit CollectFees(positionId, amount0, amount1);
    }

    function swap(
        bytes32 poolId,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external nonReentrant returns (int256 amount0, int256 amount1) {
        Pool storage pool = pools[poolId];
        require(pool.initialized, "Pool not initialized");
        require(amountIn > 0, "Zero input");

        IERC20 tokenIn = IERC20(zeroForOne ? pool.token0 : pool.token1);
        IERC20 tokenOut = IERC20(zeroForOne ? pool.token1 : pool.token0);

        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 remainingIn = amountIn;
        uint256 totalOut = 0;
        uint160 sqrtPriceCurrent = pool.sqrtPriceX96;
        int24 tickCurrent = pool.currentTick;
        uint128 liquidityCurrent = pool.liquidity;
        uint256 feeGrowthGlobal0 = pool.feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1 = pool.feeGrowthGlobal1X128;

        while (remainingIn > 0 && liquidityCurrent > 0) {
            int24 nextTick = _nextInitializedTick(poolId, tickCurrent, zeroForOne);
            uint160 sqrtPriceTarget = _getSqrtPriceAtTick(nextTick);

            uint256 feeAmount = Math.mulDiv(remainingIn, pool.fee, 1_000_000);
            uint256 amountInAfterFee = remainingIn - feeAmount;

            uint256 amountInStep;
            uint256 amountOutStep;

            if (zeroForOne) {
                uint256 maxAmountIn = _getAmount0ForLiquidity(sqrtPriceTarget, sqrtPriceCurrent, liquidityCurrent);
                if (amountInAfterFee >= maxAmountIn) {
                    amountInStep = maxAmountIn;
                    amountOutStep = _getAmount1ForLiquidity(sqrtPriceTarget, sqrtPriceCurrent, liquidityCurrent);
                    sqrtPriceCurrent = sqrtPriceTarget;

                    feeAmount = Math.mulDiv(amountInStep, pool.fee, 1_000_000 - pool.fee);
                    remainingIn -= (amountInStep + feeAmount);

                    if (liquidityCurrent > 0) {
                        feeGrowthGlobal0 += Math.mulDiv(feeAmount, Q128, liquidityCurrent);
                    }

                    TickInfo storage nextTickInfo = ticks[poolId][nextTick];
                    if (nextTickInfo.initialized) {
                        liquidityCurrent = _addDelta(liquidityCurrent, -nextTickInfo.liquidityNet);
                    }
                    tickCurrent = nextTick - 1;
                } else {
                    uint160 sqrtPriceNew = _getNextSqrtPriceFromInput(sqrtPriceCurrent, liquidityCurrent, amountInAfterFee, true);
                    amountOutStep = _getAmount1ForLiquidity(sqrtPriceNew, sqrtPriceCurrent, liquidityCurrent);
                    sqrtPriceCurrent = sqrtPriceNew;
                    tickCurrent = _getTickAtSqrtPrice(sqrtPriceCurrent);

                    if (liquidityCurrent > 0) {
                        feeGrowthGlobal0 += Math.mulDiv(feeAmount, Q128, liquidityCurrent);
                    }
                    remainingIn = 0;
                }
            } else {
                uint256 maxAmountIn = _getAmount1ForLiquidity(sqrtPriceCurrent, sqrtPriceTarget, liquidityCurrent);
                if (amountInAfterFee >= maxAmountIn) {
                    amountInStep = maxAmountIn;
                    amountOutStep = _getAmount0ForLiquidity(sqrtPriceCurrent, sqrtPriceTarget, liquidityCurrent);
                    sqrtPriceCurrent = sqrtPriceTarget;

                    feeAmount = Math.mulDiv(amountInStep, pool.fee, 1_000_000 - pool.fee);
                    remainingIn -= (amountInStep + feeAmount);

                    if (liquidityCurrent > 0) {
                        feeGrowthGlobal1 += Math.mulDiv(feeAmount, Q128, liquidityCurrent);
                    }

                    TickInfo storage nextTickInfo = ticks[poolId][nextTick];
                    if (nextTickInfo.initialized) {
                        liquidityCurrent = _addDelta(liquidityCurrent, nextTickInfo.liquidityNet);
                    }
                    tickCurrent = nextTick;
                } else {
                    uint160 sqrtPriceNew = _getNextSqrtPriceFromInput(sqrtPriceCurrent, liquidityCurrent, amountInAfterFee, false);
                    amountOutStep = _getAmount0ForLiquidity(sqrtPriceCurrent, sqrtPriceNew, liquidityCurrent);
                    sqrtPriceCurrent = sqrtPriceNew;
                    tickCurrent = _getTickAtSqrtPrice(sqrtPriceCurrent);

                    if (liquidityCurrent > 0) {
                        feeGrowthGlobal1 += Math.mulDiv(feeAmount, Q128, liquidityCurrent);
                    }
                    remainingIn = 0;
                }
            }

            totalOut += amountOutStep;
        }

        require(totalOut >= amountOutMinimum, "Slippage exceeded");

        pool.sqrtPriceX96 = sqrtPriceCurrent;
        pool.currentTick = tickCurrent;
        pool.liquidity = liquidityCurrent;
        pool.feeGrowthGlobal0X128 = feeGrowthGlobal0;
        pool.feeGrowthGlobal1X128 = feeGrowthGlobal1;

        if (remainingIn > 0) {
            tokenIn.safeTransfer(msg.sender, remainingIn);
        }
        tokenOut.safeTransfer(msg.sender, totalOut);

        amount0 = zeroForOne ? int256(amountIn - remainingIn) : -int256(totalOut);
        amount1 = zeroForOne ? -int256(totalOut) : int256(amountIn - remainingIn);

        emit Swap(poolId, msg.sender, zeroForOne, amount0, amount1);
    }

    function _updateTick(
        bytes32 poolId,
        int24 tick,
        uint128 liquidityDelta,
        bool isLower,
        int24 currentTick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal {
        TickInfo storage info = ticks[poolId][tick];

        if (!info.initialized) {
            info.initialized = true;
            if (tick <= currentTick) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }
        }

        info.liquidityGross += liquidityDelta;
        if (isLower) {
            info.liquidityNet += int128(uint128(liquidityDelta));
        } else {
            info.liquidityNet -= int128(uint128(liquidityDelta));
        }
    }

    function _getFeeGrowthInside(
        bytes32 poolId,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 feeGrowthInside0, uint256 feeGrowthInside1) {
        Pool storage pool = pools[poolId];
        TickInfo storage lower = ticks[poolId][tickLower];
        TickInfo storage upper = ticks[poolId][tickUpper];

        uint256 feeGrowthBelow0;
        uint256 feeGrowthBelow1;
        if (pool.currentTick >= tickLower) {
            feeGrowthBelow0 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0 = pool.feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1 = pool.feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        uint256 feeGrowthAbove0;
        uint256 feeGrowthAbove1;
        if (pool.currentTick < tickUpper) {
            feeGrowthAbove0 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0 = pool.feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1 = pool.feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0 = pool.feeGrowthGlobal0X128 - feeGrowthBelow0 - feeGrowthAbove0;
        feeGrowthInside1 = pool.feeGrowthGlobal1X128 - feeGrowthBelow1 - feeGrowthAbove1;
    }

    function _calcAmountsForLiquidity(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLower,
        uint160 sqrtPriceUpper,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtPriceX96 <= sqrtPriceLower) {
            amount0 = _getAmount0ForLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
        } else if (sqrtPriceX96 < sqrtPriceUpper) {
            amount0 = _getAmount0ForLiquidity(sqrtPriceX96, sqrtPriceUpper, liquidity);
            amount1 = _getAmount1ForLiquidity(sqrtPriceLower, sqrtPriceX96, liquidity);
        } else {
            amount1 = _getAmount1ForLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
        }
    }

    function _getAmount0ForLiquidity(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256) {
        if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        return Math.mulDiv(uint256(liquidity) * Q96, sqrtPriceBX96 - sqrtPriceAX96, sqrtPriceBX96) / sqrtPriceAX96;
    }

    function _getAmount1ForLiquidity(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256) {
        if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        return Math.mulDiv(liquidity, sqrtPriceBX96 - sqrtPriceAX96, Q96);
    }

    function _getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160) {
        if (zeroForOne) {
            uint256 product = amountIn * sqrtPriceX96;
            uint256 denominator = uint256(liquidity) * Q96 + product;
            return uint160(Math.mulDiv(uint256(liquidity) * Q96, sqrtPriceX96, denominator));
        } else {
            uint256 quotient = Math.mulDiv(amountIn, Q96, liquidity);
            return uint160(uint256(sqrtPriceX96) + quotient);
        }
    }

    function _getSqrtPriceAtTick(int24 tick) internal pure returns (uint160) {
        uint256 absTick = tick < 0 ? uint256(uint24(-tick)) : uint256(uint24(tick));
        require(absTick <= uint256(uint24(MAX_TICK)), "Tick OOB");

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        return uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    function _getTickAtSqrtPrice(uint160 sqrtPriceX96) internal pure returns (int24) {
        uint256 ratio = uint256(sqrtPriceX96) << 32;
        uint256 r = ratio;
        uint256 msb = 0;

        assembly {
            let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(5, gt(r, 0xFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(4, gt(r, 0xFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(3, gt(r, 0xFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(2, gt(r, 0xF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(1, gt(r, 0x3))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := gt(r, 0x1)
            msb := or(msb, f)
        }

        if (msb >= 128) r = ratio >> (msb - 127);
        else r = ratio << (127 - msb);

        int256 log_2 = (int256(msb) - 128) << 64;

        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(63, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(62, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(61, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(60, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(59, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(58, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(57, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(56, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(55, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(54, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(53, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(52, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(51, f))
            r := shr(f, r)
        }

        int256 log_sqrt10001 = log_2 * 255738958999603826347141;

        int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
        int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

        return tickLow == tickHi ? tickLow : (_getSqrtPriceAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow);
    }

    function _nextInitializedTick(
        bytes32 poolId,
        int24 tick,
        bool zeroForOne
    ) internal view returns (int24) {
        int24 next = tick;
        if (zeroForOne) {
            next = ((next / TICK_SPACING) - 1) * TICK_SPACING;
            while (next >= MIN_TICK && !ticks[poolId][next].initialized) {
                next -= TICK_SPACING;
            }
            return next < MIN_TICK ? MIN_TICK : next;
        } else {
            next = ((next / TICK_SPACING) + 1) * TICK_SPACING;
            while (next <= MAX_TICK && !ticks[poolId][next].initialized) {
                next += TICK_SPACING;
            }
            return next > MAX_TICK ? MAX_TICK : next;
        }
    }

    function _addDelta(uint128 x, int128 y) internal pure returns (uint128) {
        if (y < 0) {
            uint128 z = x - uint128(-y);
            require(z < x, "Liquidity underflow");
            return z;
        } else {
            uint128 z = x + uint128(y);
            require(z >= x, "Liquidity overflow");
            return z;
        }
    }
}