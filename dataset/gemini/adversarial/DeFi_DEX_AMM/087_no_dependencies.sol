// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDEX {
    address public owner;
    mapping(address => mapping(address => uint256)) public reserves; // reserves[tokenA][tokenB]

    event Deposit(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event Swap(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event Withdrawal(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);

    constructor() {
        owner = msg.sender;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {
        require(tokenA != tokenB, "TokenA and TokenB cannot be the same");
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");

        // ERC20 transferFrom
        (bool successA, ) = tokenA.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amountA));
        require(successA, "Failed to transfer tokenA from user");
        (bool successB, ) = tokenB.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amountB));
        require(successB, "Failed to transfer tokenB from user");

        reserves[tokenA][tokenB] += amountA;
        reserves[tokenB][tokenA] += amountB;

        emit Deposit(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {
        require(tokenA != tokenB, "TokenA and TokenB cannot be the same");
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");
        require(reserves[tokenA][tokenB] >= amountA, "Insufficient reserves of tokenA");
        require(reserves[tokenB][tokenA] >= amountB, "Insufficient reserves of tokenB");

        reserves[tokenA][tokenB] -= amountA;
        reserves[tokenB][tokenA] -= amountB;

        // ERC20 transfer
        (bool successA, ) = tokenA.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amountA));
        require(successA, "Failed to transfer tokenA to user");
        (bool successB, ) = tokenB.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amountB));
        require(successB, "Failed to transfer tokenB to user");

        emit Withdrawal(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
        require(tokenIn != tokenOut, "TokenIn and TokenOut cannot be the same");
        require(amountIn > 0, "AmountIn must be greater than zero");

        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];
        require(reserveIn > 0 && reserveOut > 0, "Pool does not exist or has zero liquidity");

        // ERC20 transferFrom
        (bool successIn, ) = tokenIn.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amountIn));
        require(successIn, "Failed to transfer tokenIn from user");

        // Calculate amountOut using the constant product formula (x*y = k)
        // amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut > 0, "Swap amount is too small");

        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;

        // ERC20 transfer
        (bool successOut, ) = tokenOut.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amountOut));
        require(successOut, "Failed to transfer tokenOut to user");

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint256) {
        return reserves[tokenA][tokenB];
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        require(tokenIn != tokenOut, "TokenIn and TokenOut cannot be the same");
        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];
        require(reserveIn > 0 && reserveOut > 0, "Pool does not exist or has zero liquidity");
        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}