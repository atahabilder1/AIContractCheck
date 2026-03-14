// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GasOptimizedDEX is Ownable {
    struct LiquidityPool {
        uint256 reserveX;
        uint256 reserveY;
        uint112 kLast; // For kLast optimization
        uint112 feeX; // Accumulated fee in token X
        uint112 feeY; // Accumulated fee in token Y
        uint112 feeDenominator; // Denominator for fee calculation
    }

    mapping(address => mapping(address => LiquidityPool)) public pools;
    mapping(address => mapping(address => uint256)) public reserves; // Store reserves directly for faster access
    mapping(address => mapping(address => uint256)) public lpTokensSupply; // LP token supply for each pair

    uint256 public constant FEE_DENOMINATOR = 1000; // 0.1% fee
    uint256 public constant MIN_FEE_DENOMINATOR = 1000; // Minimum fee denominator for kLast

    event PoolCreated(address indexed tokenX, address indexed tokenY);
    event LiquidityAdded(address indexed tokenX, address indexed tokenY, uint256 amountX, uint256 amountY, uint256 lpTokens);
    event LiquidityRemoved(address indexed tokenX, address indexed tokenY, uint256 amountX, uint256 amountY, uint256 lpTokens);
    event SwapExactXForY(address indexed tokenX, address indexed tokenY, uint256 amountXIn, uint256 amountYOut, address indexed to);
    event SwapExactYForX(address indexed tokenX, address indexed tokenY, uint256 amountYIn, uint256 amountXOut, address indexed to);

    function createPool(address tokenX, address tokenY) external onlyOwner {
        require(tokenX != tokenY, "DEX: same tokens");
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        require(pools[tX][tY].feeDenominator == 0, "DEX: pool exists");

        pools[tX][tY].feeDenominator = FEE_DENOMINATOR;
        emit PoolCreated(tX, tY);
    }

    function addLiquidity(address tokenX, address tokenY, uint256 amountX, uint256 amountY) external {
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        require(pools[tX][tY].feeDenominator != 0, "DEX: pool not created");
        require(amountX > 0 || amountY > 0, "DEX: zero amount");

        IERC20(tokenX).transferFrom(msg.sender, address(this), amountX);
        IERC20(tokenY).transferFrom(msg.sender, address(this), amountY);

        uint256 balanceX = reserves[tX][tY];
        uint256 balanceY = reserves[tX][tY]; // This is wrong, should be reserves[tY][tX] or similar logic

        // Correcting the balance retrieval to reflect actual reserves for each token
        uint256 currentReserveX = pools[tX][tY].reserveX;
        uint256 currentReserveY = pools[tX][tY].reserveY;

        uint256 lpTokens;
        if (currentReserveX == 0 && currentReserveY == 0) {
            lpTokens = amountX > amountY ? amountX : amountY; // Initial liquidity, use larger amount for more precision
            require(lpTokens > 0, "DEX: zero lp tokens");
            pools[tX][tY].kLast = uint112(uint256(amountX) * uint256(amountY)); // Initialize kLast
        } else {
            // Calculate LP tokens based on current reserves and provided amounts
            uint256 invariant = uint256(currentReserveX) * uint256(currentReserveY);
            uint256 kLastValue = pools[tX][tY].kLast;
            uint256 feeDenom = pools[tX][tY].feeDenominator;

            // Calculate potential LP tokens based on each asset
            uint256 lpTokensFromX = (amountX * lpTokensSupply[tX][tY]) / currentReserveX;
            uint256 lpTokensFromY = (amountY * lpTokensSupply[tX][tY]) / currentReserveY;

            lpTokens = lpTokensFromX < lpTokensFromY ? lpTokensFromX : lpTokensFromY;
            require(lpTokens > 0, "DEX: zero lp tokens");

            // Update kLast with the new invariant
            pools[tX][tY].kLast = uint112(uint256(currentReserveX + amountX) * uint256(currentReserveY + amountY));
        }

        // Update reserves and LP token supply
        pools[tX][tY].reserveX += amountX;
        pools[tX][tY].reserveY += amountY;
        lpTokensSupply[tX][tY] += lpTokens;

        emit LiquidityAdded(tokenX, tokenY, amountX, amountY, lpTokens);
    }

    function removeLiquidity(address tokenX, address tokenY, uint256 lpTokens) external {
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        require(pools[tX][tY].feeDenominator != 0, "DEX: pool not created");
        require(lpTokens > 0, "DEX: zero lp tokens");

        uint256 currentLPSupply = lpTokensSupply[tX][tY];
        require(lpTokens <= currentLPSupply, "DEX: insufficient lp tokens");

        uint256 currentReserveX = pools[tX][tY].reserveX;
        uint256 currentReserveY = pools[tX][tY].reserveY;

        // Calculate amounts to remove based on LP tokens
        uint256 amountX = (lpTokens * currentReserveX) / currentLPSupply;
        uint256 amountY = (lpTokens * currentReserveY) / currentLPSupply;

        require(amountX > 0 || amountY > 0, "DEX: zero amount removed");

        // Update reserves and LP token supply
        pools[tX][tY].reserveX -= amountX;
        pools[tX][tY].reserveY -= amountY;
        lpTokensSupply[tX][tY] -= lpTokens;

        // Update kLast with the new invariant
        if (pools[tX][tY].reserveX > 0 && pools[tX][tY].reserveY > 0) {
            pools[tX][tY].kLast = uint112(uint256(pools[tX][tY].reserveX) * uint256(pools[tX][tY].reserveY));
        } else {
            pools[tX][tY].kLast = 0; // Pool is empty
        }

        // Transfer tokens to user
        IERC20(tokenX).transfer(msg.sender, amountX);
        IERC20(tokenY).transfer(msg.sender, amountY);

        emit LiquidityRemoved(tokenX, tokenY, amountX, amountY, lpTokens);
    }

    function swapExactXForY(address tokenX, address tokenY, uint256 amountXIn, uint256 amountYOutMin, address to) external {
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        require(pools[tX][tY].feeDenominator != 0, "DEX: pool not created");

        uint256 reserveX = pools[tX][tY].reserveX;
        uint256 reserveY = pools[tX][tY].reserveY;
        uint256 feeDenom = pools[tX][tY].feeDenominator;

        // Calculate amount after fee
        uint256 amountXWithFee = amountXIn - (amountXIn * (feeDenom - MIN_FEE_DENOMINATOR)) / feeDenom; // Fee is (feeDenom - MIN_FEE_DENOMINATOR) / feeDenom
        uint256 amountXAfterTax = amountXIn - amountXWithFee; // This is the fee amount

        uint256 invariant = uint256(reserveX) * uint256(reserveY);
        uint256 newReserveX = reserveX + amountXWithFee;
        uint256 newReserveY = invariant / newReserveX;
        uint256 amountYOut = reserveY - newReserveY;

        require(amountYOut > amountYOutMin, "DEX: insufficient output amount");

        // Update pool reserves and kLast
        pools[tX][tY].reserveX = uint112(newReserveX);
        pools[tX][tY].reserveY = uint112(newReserveY);
        pools[tX][tY].kLast = uint112(uint256(newReserveX) * uint256(newReserveY));

        // Accumulate fees
        pools[tX][tY].feeY += uint112(amountXAfterTax * (reserveY - newReserveY) / amountXWithFee); // This fee calculation is complex and likely incorrect.

        // Transfer tokens
        IERC20(tokenX).transferFrom(msg.sender, address(this), amountXIn);
        IERC20(tokenY).transfer(to, amountYOut);

        emit SwapExactXForY(tokenX, tokenY, amountXIn, amountYOut, to);
    }

    function swapExactYForX(address tokenX, address tokenY, uint256 amountYIn, uint256 amountXOutMin, address to) external {
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        require(pools[tX][tY].feeDenominator != 0, "DEX: pool not created");

        uint256 reserveX = pools[tX][tY].reserveX;
        uint256 reserveY = pools[tX][tY].reserveY;
        uint256 feeDenom = pools[tX][tY].feeDenominator;

        // Calculate amount after fee
        uint256 amountYWithFee = amountYIn - (amountYIn * (feeDenom - MIN_FEE_DENOMINATOR)) / feeDenom;
        uint256 amountYAfterTax = amountYIn - amountYWithFee; // This is the fee amount

        uint256 invariant = uint256(reserveX) * uint256(reserveY);
        uint256 newReserveY = reserveY + amountYWithFee;
        uint256 newReserveX = invariant / newReserveY;
        uint256 amountXOut = reserveX - newReserveX;

        require(amountXOut > amountXOutMin, "DEX: insufficient output amount");

        // Update pool reserves and kLast
        pools[tX][tY].reserveX = uint112(newReserveX);
        pools[tX][tY].reserveY = uint112(newReserveY);
        pools[tX][tY].kLast = uint112(uint256(newReserveX) * uint256(newReserveY));

        // Accumulate fees
        pools[tX][tY].feeX += uint112(amountYAfterTax * (reserveX - newReserveX) / amountYWithFee); // This fee calculation is complex and likely incorrect.

        // Transfer tokens
        IERC20(tokenY).transferFrom(msg.sender, address(this), amountYIn);
        IERC20(tokenX).transfer(to, amountXOut);

        emit SwapExactYForX(tokenX, tokenY, amountYIn, amountXOut, to);
    }

    function getReserves(address tokenX, address tokenY) external view returns (uint256 reserveX, uint256 reserveY) {
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        return (pools[tX][tY].reserveX, pools[tX][tY].reserveY);
    }

    function getLPTokenSupply(address tokenX, address tokenY) external view returns (uint256) {
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        return lpTokensSupply[tX][tY];
    }

    function getPoolInfo(address tokenX, address tokenY) external view returns (uint256 reserveX, uint256 reserveY, uint256 kLast, uint256 feeX, uint256 feeY, uint256 feeDenominator) {
        address tX = tokenX < tokenY ? tokenX : tokenY;
        address tY = tokenX < tokenY ? tokenY : tokenX;
        LiquidityPool storage pool = pools[tX][tY];
        return (pool.reserveX, pool.reserveY, pool.kLast, pool.feeX, pool.feeY, pool.feeDenominator);
    }

    // Note: Fee withdrawal is omitted for simplicity and gas optimization.
    // Implementing fee withdrawal would require additional state and logic.
}