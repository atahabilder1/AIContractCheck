// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Automated Market Maker with Concentrated Liquidity
contract ConcentratedAMM {
    address public token0;
    address public token1;
    address public owner;

    uint256 public fee = 30; // 0.3%
    uint256 public constant FEE_DENOMINATOR = 10000;

    struct Position {
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
        uint256 feeGrowthInside0;
        uint256 feeGrowthInside1;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct Tick {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0;
        uint256 feeGrowthOutside1;
        bool initialized;
    }

    int24 public currentTick;
    uint160 public sqrtPriceX96;
    uint128 public liquidity;

    mapping(bytes32 => Position) public positions;
    mapping(int24 => Tick) public ticks;

    uint256 public feeGrowthGlobal0;
    uint256 public feeGrowthGlobal1;

    event Mint(address indexed owner, int24 tickLower, int24 tickUpper, uint128 amount, uint256 amount0, uint256 amount1);
    event Burn(address indexed owner, int24 tickLower, int24 tickUpper, uint128 amount, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick);

    constructor(address _token0, address _token1, uint160 _sqrtPriceX96) {
        require(_token0 < _token1, "Invalid token order");
        token0 = _token0;
        token1 = _token1;
        sqrtPriceX96 = _sqrtPriceX96;
        currentTick = getTickAtSqrtRatio(_sqrtPriceX96);
        owner = msg.sender;
    }

    function getPositionKey(address ownerAddr, int24 tickLower, int24 tickUpper) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(ownerAddr, tickLower, tickUpper));
    }

    function mint(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {
        require(tickLower < tickUpper, "Invalid tick range");
        require(amount > 0, "Amount must be positive");

        // Update ticks
        _updateTick(tickLower, int128(uint128(amount)), false);
        _updateTick(tickUpper, int128(uint128(amount)), true);

        // Calculate amounts needed
        (amount0, amount1) = _getAmountsForLiquidity(sqrtPriceX96, tickLower, tickUpper, amount);

        // Update position
        bytes32 positionKey = getPositionKey(msg.sender, tickLower, tickUpper);
        positions[positionKey].liquidity += amount;
        positions[positionKey].tickLower = tickLower;
        positions[positionKey].tickUpper = tickUpper;

        // Update global liquidity if in range
        if (currentTick >= tickLower && currentTick < tickUpper) {
            liquidity += amount;
        }

        // Transfer tokens
        if (amount0 > 0) IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        emit Mint(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
    }

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {
        bytes32 positionKey = getPositionKey(msg.sender, tickLower, tickUpper);
        Position storage position = positions[positionKey];
        require(position.liquidity >= amount, "Insufficient liquidity");

        // Update ticks
        _updateTick(tickLower, -int128(uint128(amount)), false);
        _updateTick(tickUpper, -int128(uint128(amount)), true);

        // Calculate amounts to return
        (amount0, amount1) = _getAmountsForLiquidity(sqrtPriceX96, tickLower, tickUpper, amount);

        // Update position
        position.liquidity -= amount;

        // Update global liquidity if in range
        if (currentTick >= tickLower && currentTick < tickUpper) {
            liquidity -= amount;
        }

        // Transfer tokens
        if (amount0 > 0) IERC20(token0).transfer(msg.sender, amount0);
        if (amount1 > 0) IERC20(token1).transfer(msg.sender, amount1);

        emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
    }

    function swap(
        bool zeroForOne,
        int256 amountSpecified
    ) external returns (int256 amount0, int256 amount1) {
        require(amountSpecified != 0, "Amount must be non-zero");

        // Simplified swap logic
        uint256 amountIn = zeroForOne ? uint256(amountSpecified) : uint256(-amountSpecified);
        uint256 feeAmount = amountIn * fee / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - feeAmount;

        // Calculate output (simplified constant product)
        uint256 amountOut = amountInAfterFee * 997 / 1000; // Simplified

        if (zeroForOne) {
            amount0 = int256(amountIn);
            amount1 = -int256(amountOut);
            IERC20(token0).transferFrom(msg.sender, address(this), amountIn);
            IERC20(token1).transfer(msg.sender, amountOut);
            feeGrowthGlobal0 += feeAmount * 1e18 / liquidity;
        } else {
            amount0 = -int256(amountOut);
            amount1 = int256(amountIn);
            IERC20(token1).transferFrom(msg.sender, address(this), amountIn);
            IERC20(token0).transfer(msg.sender, amountOut);
            feeGrowthGlobal1 += feeAmount * 1e18 / liquidity;
        }

        emit Swap(msg.sender, amount0, amount1, sqrtPriceX96, liquidity, currentTick);
    }

    function _updateTick(int24 tick, int128 liquidityDelta, bool upper) internal {
        Tick storage tickInfo = ticks[tick];
        tickInfo.liquidityGross += uint128(liquidityDelta > 0 ? liquidityDelta : -liquidityDelta);
        tickInfo.liquidityNet += upper ? -liquidityDelta : liquidityDelta;
        if (!tickInfo.initialized) tickInfo.initialized = true;
    }

    function _getAmountsForLiquidity(
        uint160,
        int24,
        int24,
        uint128 amount
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Simplified calculation
        amount0 = uint256(amount) / 2;
        amount1 = uint256(amount) / 2;
    }

    function getTickAtSqrtRatio(uint160 sqrtRatioX96) internal pure returns (int24) {
        // Simplified tick calculation
        return int24(int256(uint256(sqrtRatioX96) / 1e18));
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
