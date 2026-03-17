// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract SimpleAMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    constructor(address _token0, address _token1) {
        require(_token0 != address(0) && _token1 != address(0) && _token0 != _token1, "BAD_TOKENS");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 shares) {
        require(amount0 > 0 && amount1 > 0, "AMOUNTS");
        require(token0.transferFrom(msg.sender, address(this), amount0), "T0_XFER");
        require(token1.transferFrom(msg.sender, address(this), amount1), "T1_XFER");

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        if (totalLiquidity == 0) {
            shares = sqrt(amount0 * amount1);
        } else {
            shares = min((amount0 * totalLiquidity) / _reserve0, (amount1 * totalLiquidity) / _reserve1);
        }
        require(shares > 0, "SHARES");

        liquidity[msg.sender] += shares;
        totalLiquidity += shares;

        _update();
    }

    function removeLiquidity(uint256 shares) external returns (uint256 amount0, uint256 amount1) {
        require(shares > 0 && shares <= liquidity[msg.sender], "SHARES");
        amount0 = (shares * reserve0) / totalLiquidity;
        amount1 = (shares * reserve1) / totalLiquidity;

        liquidity[msg.sender] -= shares;
        totalLiquidity -= shares;

        require(token0.transfer(msg.sender, amount0), "T0_XFER");
        require(token1.transfer(msg.sender, amount1), "T1_XFER");

        _update();
    }

    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        require(amountIn > 0, "AMOUNT");
        if (tokenIn == address(token0)) {
            require(token0.transferFrom(msg.sender, address(this), amountIn), "T0_XFER");
            uint256 _reserveIn = reserve0;
            uint256 _reserveOut = reserve1;
            amountOut = (_reserveOut * amountIn) / (_reserveIn + amountIn);
            require(amountOut > 0 && amountOut < _reserveOut, "OUT");
            require(token1.transfer(msg.sender, amountOut), "T1_XFER");
        } else if (tokenIn == address(token1)) {
            require(token1.transferFrom(msg.sender, address(this), amountIn), "T1_XFER");
            uint256 _reserveIn = reserve1;
            uint256 _reserveOut = reserve0;
            amountOut = (_reserveOut * amountIn) / (_reserveIn + amountIn);
            require(amountOut > 0 && amountOut < _reserveOut, "OUT");
            require(token0.transfer(msg.sender, amountOut), "T0_XFER");
        } else {
            revert("INVALID_TOKEN");
        }
        _update();
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function _update() internal {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}