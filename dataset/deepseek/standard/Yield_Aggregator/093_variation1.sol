// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);
}

contract Vault is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public lpToken;
    IUniswapV2Router public uniswapV2Router;
    address public uniswapV2Pair;

    constructor(address _lpToken, address _uniswapV2Router, address _uniswapV2Pair) {
        lpToken = IERC20(_lpToken);
        uniswapV2Router = IUniswapV2Router(_uniswapV2Router);
        uniswapV2Pair = _uniswapV2Pair;
    }

    function addLiquidity(uint256 amount) external onlyOwner {
        lpToken.safeTransfer(uniswapV2Pair, amount);
        IUniswapV2Pair(uniswapV2Pair).mint(address(this));
    }

    function removeLiquidity(uint256 liquidity) external onlyOwner {
        IUniswapV2Pair(uniswapV2Pair).burn(address(this));
    }

    function getReserves() public view returns (uint112 reserve0, uint112 reserve1) {
        (reserve0, reserve1, ) = IUniswapV2Pair(uniswapV2Pair).getReserves();
    }

    function autoCompound() external onlyOwner {
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1) = getReserves();

        if (reserve0 > 0 && reserve1 > 0) {
            uint256 amountToAdd = 0;
            if (reserve0 > 0) {
                amountToAdd = (reserve0 * 997) / (1000 * 2); // 99.7% of half of reserve0
            } else if (reserve1 > 0) {
                amountToAdd = (reserve1 * 997) / (1000 * 2); // 99.7% of half of reserve1
            }

            if (amountToAdd > 0) {
                uniswapV2Router.addLiquidity(
                    IUniswapV2Pair(uniswapV2Pair).token0(),
                    IUniswapV2Pair(uniswapV2Pair).token1(),
                    amountToAdd,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
            }
        }
    }
}