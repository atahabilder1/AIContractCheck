// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDEX {
    address public token1;
    address public token2;
    uint256 public reserve1;
    uint256 public reserve2;

    event Swap(address indexed sender, address indexed fromToken, address indexed toToken, uint256 amountIn, uint256 amountOut);
    event AddLiquidity(address indexed provider, uint256 amountToken1, uint256 amountToken2);
    event RemoveLiquidity(address indexed provider, uint256 amountToken1, uint256 amountToken2);

    constructor(address _token1, address _token2) {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(uint256 amountToken1, uint256 amountToken2) external {
        require(amountToken1 > 0 && amountToken2 > 0, "Invalid amounts");

        IERC20(token1).transferFrom(msg.sender, address(this), amountToken1);
        IERC20(token2).transferFrom(msg.sender, address(this), amountToken2);

        reserve1 += amountToken1;
        reserve2 += amountToken2;

        emit AddLiquidity(msg.sender, amountToken1, amountToken2);
    }

    function removeLiquidity(uint256 amountToken1, uint256 amountToken2) external {
        require(amountToken1 <= reserve1 && amountToken2 <= reserve2, "Insufficient reserves");

        IERC20(token1).transfer(msg.sender, amountToken1);
        IERC20(token2).transfer(msg.sender, amountToken2);

        reserve1 -= amountToken1;
        reserve2 -= amountToken2;

        emit RemoveLiquidity(msg.sender, amountToken1, amountToken2);
    }

    function swap(address fromToken, uint256 amountIn) external returns (uint256 amountOut) {
        require(fromToken == token1 || fromToken == token2, "Invalid token");

        bool isFromToken1 = fromToken == token1;
        (uint256 reserveIn, uint256 reserveOut) = isFromToken1 ? (reserve1, reserve2) : (reserve2, reserve1);

        require(amountIn > 0 && amountIn <= reserveIn, "Invalid amount");

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);

        require(amountOut > 0, "Insufficient output amount");

        IERC20(fromToken).transferFrom(msg.sender, address(this), amountIn);
        IERC20(isFromToken1 ? token2 : token1).transfer(msg.sender, amountOut);

        if (isFromToken1) {
            reserve1 += amountIn;
            reserve2 -= amountOut;
        } else {
            reserve2 += amountIn;
            reserve1 -= amountOut;
        }

        emit Swap(msg.sender, fromToken, isFromToken1 ? token2 : token1, amountIn, amountOut);
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}