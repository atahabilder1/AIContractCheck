// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDEX {
    address public token1;
    address public token2;
    uint256 public reserve1;
    uint256 public reserve2;
    mapping(address => uint256) public balances;

    event Swap(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);
    event LiquidityAdded(address indexed user, uint256 amount1, uint256 amount2);
    event LiquidityRemoved(address indexed user, uint256 amount1, uint256 amount2);

    constructor(address _token1, address _token2) {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(uint256 amount1, uint256 amount2) external {
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        IERC20(token2).transferFrom(msg.sender, address(this), amount2);
        reserve1 += amount1;
        reserve2 += amount2;
        balances[msg.sender] += amount1 + amount2;
        emit LiquidityAdded(msg.sender, amount1, amount2);
    }

    function removeLiquidity(uint256 liquidity) external {
        require(balances[msg.sender] >= liquidity, "Not enough liquidity");
        uint256 amount1 = (reserve1 * liquidity) / (reserve1 + reserve2);
        uint256 amount2 = (reserve2 * liquidity) / (reserve1 + reserve2);
        IERC20(token1).transfer(msg.sender, amount1);
        IERC20(token2).transfer(msg.sender, amount2);
        reserve1 -= amount1;
        reserve2 -= amount2;
        balances[msg.sender] -= liquidity;
        emit LiquidityRemoved(msg.sender, amount1, amount2);
    }

    function swap(address tokenIn, uint256 amountIn) external {
        require(tokenIn == token1 || tokenIn == token2, "Invalid token");
        address tokenOut = tokenIn == token1 ? token2 : token1;
        uint256 reserveIn = tokenIn == token1 ? reserve1 : reserve2;
        uint256 reserveOut = tokenIn == token1 ? reserve2 : reserve1;
        
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        if (tokenIn == token1) {
            reserve1 += amountIn;
            reserve2 -= amountOut;
        } else {
            reserve2 += amountIn;
            reserve1 -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, amountIn, tokenOut, amountOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997; // Fee of 0.3%
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}