// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ConstantProductAMM {
    uint256 public reserveA;
    uint256 public reserveB;
    mapping(address => uint256) public liquidity;
    uint256 public totalLiquidity;

    event Swap(address indexed user, uint256 amountIn, uint256 amountOut);
    event AddLiquidity(address indexed user, uint256 amountA, uint256 amountB);
    event RemoveLiquidity(address indexed user, uint256 amountA, uint256 amountB);

    function _updateReserves(uint256 _reserveA, uint256 _reserveB) private {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");
        
        if (totalLiquidity == 0) {
            totalLiquidity = amountA;
        } else {
            uint256 amountBOptimal = (amountA * reserveB) / reserveA;
            require(amountB >= amountBOptimal, "Insufficient B amount");
        }

        liquidity[msg.sender] += amountA;
        totalLiquidity += amountA;

        _updateReserves(reserveA + amountA, reserveB + amountB);

        emit AddLiquidity(msg.sender, amountA, amountB);
    }

    function removeLiquidity(uint256 amountA) external {
        require(liquidity[msg.sender] >= amountA, "Insufficient liquidity");

        uint256 amountB = (amountA * reserveB) / reserveA;

        liquidity[msg.sender] -= amountA;
        totalLiquidity -= amountA;

        _updateReserves(reserveA - amountA, reserveB - amountB);

        emit RemoveLiquidity(msg.sender, amountA, amountB);
    }

    function swap(uint256 amountIn, bool swapAForB) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than zero");

        if (swapAForB) {
            uint256 amountInWithFee = amountIn * 997;
            amountOut = (amountInWithFee * reserveB) / (reserveA * 1000 + amountInWithFee);
            _updateReserves(reserveA + amountIn, reserveB - amountOut);
        } else {
            uint256 amountInWithFee = amountIn * 997;
            amountOut = (amountInWithFee * reserveA) / (reserveB * 1000 + amountInWithFee);
            _updateReserves(reserveA - amountOut, reserveB + amountIn);
        }

        emit Swap(msg.sender, amountIn, amountOut);
    }
}