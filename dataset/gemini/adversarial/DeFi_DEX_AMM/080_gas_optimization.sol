// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MinimalAMM {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function _getReserves() internal view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = tokenA.balanceOf(address(this));
        _reserveB = tokenB.balanceOf(address(this));
    }

    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return _getReserves();
    }

    function getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut) internal pure returns (uint256 amountOut) {
        require(_amountIn > 0, "MinimalAMM: IN_AMOUNT_ZERO");
        require(_reserveIn > 0 && _reserveOut > 0, "MinimalAMM: RESERVES_ZERO");

        uint256 amountInWithFee = _amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = _reserveIn + amountInWithFee;

        amountOut = numerator / denominator;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        address tokenIn,
        address tokenOut
    ) external returns (uint256 amountOut) {
        IERC20 _tokenIn = IERC20(tokenIn);
        IERC20 _tokenOut = IERC20(tokenOut);

        require(
            (tokenIn == address(tokenA) && tokenOut == address(tokenB)) ||
            (tokenIn == address(tokenB) && tokenOut == address(tokenA)),
            "MinimalAMM: INVALID_TOKEN_PAIR"
        );

        (uint256 _reserveIn, uint256 _reserveOut) = tokenIn == address(tokenA)
            ? _getReserves()
            : (reserveB, reserveA); // This is incorrect, should be _getReserves()

        // Re-fetch reserves to ensure accuracy after potential prior swaps if this function were to be called multiple times in a transaction
        (_reserveIn, _reserveOut) = tokenIn == address(tokenA)
            ? _getReserves()
            : (_getReserves().1, _getReserves().0);


        amountOut = getAmountOut(amountIn, _reserveIn, _reserveOut);
        require(amountOut >= amountOutMin, "MinimalAMM: AMOUNT_OUT_MIN_NOT_MET");

        _tokenIn.transferFrom(msg.sender, address(this), amountIn);

        _tokenOut.transfer(to, amountOut);

        // Update reserves (implicitly handled by token balances after transferFrom and transfer)
        // No explicit storage writes here to save gas.

        return amountOut;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 || amountB > 0, "MinimalAMM: AMOUNTS_ZERO");
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
    }

    function removeLiquidity() external {
        // This is a simplified example and doesn't handle LP tokens or proportional removal.
        // A real DEX would require LP tokens for managing liquidity.
        uint256 _reserveA = tokenA.balanceOf(address(this));
        uint256 _reserveB = tokenB.balanceOf(address(this));

        tokenA.transfer(msg.sender, _reserveA);
        tokenB.transfer(msg.sender, _reserveB);
    }
}