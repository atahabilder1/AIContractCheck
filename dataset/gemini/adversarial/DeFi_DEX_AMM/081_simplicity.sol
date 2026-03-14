// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDEX {
    address public tokenA;
    address public tokenB;

    // reserves[0] is reserve of tokenA, reserves[1] is reserve of tokenB
    uint256[2] public reserves;

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    // Function to add liquidity
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        // Basic check to prevent adding zero liquidity
        require(amountA > 0 && amountB > 0, "Amounts must be positive");

        // Transfer tokens from user to the contract
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        // Update reserves
        reserves[0] += amountA;
        reserves[1] += amountB;
    }

    // Function to remove liquidity
    function removeLiquidity(uint256 amountA, uint256 amountB) external {
        // Basic check to prevent removing zero liquidity
        require(amountA > 0 && amountB > 0, "Amounts must be positive");

        // Ensure contract has enough reserves
        require(reserves[0] >= amountA, "Insufficient reserve of tokenA");
        require(reserves[1] >= amountB, "Insufficient reserve of tokenB");

        // Transfer tokens from contract to user
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        // Update reserves
        reserves[0] -= amountA;
        reserves[1] -= amountB;
    }

    // Function to swap tokenA for tokenB
    function swapAforB(uint256 amountAIn) external returns (uint256 amountBOut) {
        // Ensure contract has enough reserves of tokenA
        require(reserves[0] >= amountAIn, "Insufficient reserve of tokenA");

        // Calculate amountBOut using the constant product formula (x * y = k)
        // amountBOut = (amountAIn * reserves[1]) / (reserves[0] + amountAIn)
        amountBOut = (amountAIn * reserves[1]) / (reserves[0] + amountAIn);

        // Transfer tokens
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn);
        IERC20(tokenB).transfer(msg.sender, amountBOut);

        // Update reserves
        reserves[0] += amountAIn;
        reserves[1] -= amountBOut;

        return amountBOut;
    }

    // Function to swap tokenB for tokenA
    function swapBforA(uint256 amountBIn) external returns (uint256 amountAOut) {
        // Ensure contract has enough reserves of tokenB
        require(reserves[1] >= amountBIn, "Insufficient reserve of tokenB");

        // Calculate amountAOut using the constant product formula (x * y = k)
        // amountAOut = (amountBIn * reserves[0]) / (reserves[1] + amountBIn)
        amountAOut = (amountBIn * reserves[0]) / (reserves[1] + amountBIn);

        // Transfer tokens
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn);
        IERC20(tokenA).transfer(msg.sender, amountAOut);

        // Update reserves
        reserves[0] -= amountAOut;
        reserves[1] += amountBIn;

        return amountAOut;
    }
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}