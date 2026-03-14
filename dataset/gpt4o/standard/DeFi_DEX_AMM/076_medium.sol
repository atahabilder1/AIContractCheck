// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConcentratedLiquidityDEX {
    struct Position {
        uint256 liquidity;
        uint256 lowerTick;
        uint256 upperTick;
        address owner;
    }
    
    mapping(bytes32 => Position) public positions;
    mapping(address => mapping(address => uint256)) public reserves;
    uint256 public constant FEE_PERCENTAGE = 30; // 0.3% swap fee

    event LiquidityAdded(address indexed owner, address tokenA, address tokenB, uint256 lowerTick, uint256 upperTick, uint256 liquidity);
    event LiquidityRemoved(address indexed owner, address tokenA, address tokenB, uint256 lowerTick, uint256 upperTick, uint256 liquidity);
    event Swap(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address indexed to);

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 lowerTick, uint256 upperTick) external {
        require(tokenA != tokenB, "Identical tokens");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        bytes32 positionKey = keccak256(abi.encodePacked(tokenA, tokenB, lowerTick, upperTick, msg.sender));
        Position storage position = positions[positionKey];

        position.liquidity += amountA + amountB;
        position.lowerTick = lowerTick;
        position.upperTick = upperTick;
        position.owner = msg.sender;

        reserves[tokenA][tokenB] += amountA;
        reserves[tokenB][tokenA] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, lowerTick, upperTick, position.liquidity);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 lowerTick, uint256 upperTick) external {
        bytes32 positionKey = keccak256(abi.encodePacked(tokenA, tokenB, lowerTick, upperTick, msg.sender));
        Position storage position = positions[positionKey];

        require(position.owner == msg.sender, "Not the owner");

        uint256 liquidity = position.liquidity;

        IERC20(tokenA).transfer(msg.sender, reserves[tokenA][tokenB] * liquidity / (reserves[tokenA][tokenB] + reserves[tokenB][tokenA]));
        IERC20(tokenB).transfer(msg.sender, reserves[tokenB][tokenA] * liquidity / (reserves[tokenA][tokenB] + reserves[tokenB][tokenA]));

        reserves[tokenA][tokenB] -= reserves[tokenA][tokenB] * liquidity / (reserves[tokenA][tokenB] + reserves[tokenB][tokenA]);
        reserves[tokenB][tokenA] -= reserves[tokenB][tokenA] * liquidity / (reserves[tokenA][tokenB] + reserves[tokenB][tokenA]);

        delete positions[positionKey];

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, lowerTick, upperTick, liquidity);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) external {
        require(tokenIn != tokenOut, "Identical tokens");
        require(reserves[tokenIn][tokenOut] >= amountIn, "Insufficient liquidity");

        uint256 amountOut = getAmountOut(tokenIn, tokenOut, amountIn);
        require(amountOut >= minAmountOut, "Slippage protection");

        uint256 fee = (amountOut * FEE_PERCENTAGE) / 10000;
        amountOut -= fee;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;

        emit Swap(tokenIn, tokenOut, amountIn, amountOut, msg.sender);
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];
        uint256 amountInWithFee = amountIn * (10000 - FEE_PERCENTAGE) / 10000;
        return amountInWithFee * reserveOut / (reserveIn + amountInWithFee);
    }
}