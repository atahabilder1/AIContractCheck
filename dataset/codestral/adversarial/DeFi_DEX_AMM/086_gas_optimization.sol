// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DefiDEX {
    uint public token0Balance;
    uint public token1Balance;
    uint public liquidityTokenSupply;
    mapping(address => uint) public liquidityTokens;

    function addLiquidity(uint amount0, uint amount1) external {
        if (liquidityTokenSupply == 0) {
            liquidityTokenSupply = Math.sqrt(amount0 * amount1);
            _mint(msg.sender, liquidityTokenSupply);
        } else {
            uint liquidityMinted = Math.min((token0Balance * amount1) / token1Balance, (token1Balance * amount0) / token0Balance);
            _mint(msg.sender, liquidityMinted);
        }
        token0Balance += amount0;
        token1Balance += amount1;
    }

    function swap(uint inputAmount, uint outputTokenIndex) external {
        require(outputTokenIndex == 0 || outputTokenIndex == 1, "Invalid output token index");

        uint inputReserve = (outputTokenIndex == 0) ? token1Balance : token0Balance;
        uint outputReserve = (outputTokenIndex == 0) ? token0Balance : token1Balance;

        uint inputAmountWithFee = inputAmount * 997;
        uint numerator = inputAmountWithFee * outputReserve;
        uint denominator = inputReserve * 1000 + inputAmountWithFee;

        uint outputAmount = numerator / denominator;

        if (outputTokenIndex == 0) {
            _transferFrom(msg.sender, token0Balance - outputAmount);
            _transferTo(msg.sender, outputAmount);
        } else {
            _transferFrom(msg.sender, token1Balance - outputAmount);
            _transferTo(msg.sender, outputAmount);
        }
    }

    function _mint(address to, uint amount) private {
        liquidityTokens[to] += amount;
        liquidityTokenSupply += amount;
    }

    function _transferFrom(address from, uint amount) private {
        IERC20(from).transferFrom(msg.sender, address(this), amount);
    }

    function _transferTo(address to, uint amount) private {
        IERC20(to).transfer(msg.sender, amount);
    }
}

library Math {
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}