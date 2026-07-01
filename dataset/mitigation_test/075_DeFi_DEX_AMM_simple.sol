// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ConstantProductAMM is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant FEE_NUMERATOR = 3; // 0.3% fee
    
    event Mint(address indexed to, uint256 liquidity);
    event Burn(address indexed to, uint256 liquidity, uint256 amountA, uint256 amountB);
    event Swap(address indexed user, uint256 amountAIn, uint256 amountBIn, uint256 amountAOut, uint256 amountBOut);
    event Sync(uint256 reserveA, uint256 reserveB);

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Identical tokens");
        
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external nonReentrant validAddress(to) validAmount(amountADesired) validAmount(amountBDesired) returns (uint256 liquidity) {
        require(amountAMin > 0 && amountBMin > 0, "Invalid minimum amounts");
        
        (uint256 amountA, uint256 amountB) = _calculateLiquidityAmounts(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        liquidity = _mint(to);
        
        require(liquidity > 0, "Insufficient liquidity minted");
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external nonReentrant validAddress(to) validAmount(liquidity) returns (uint256 amountA, uint256 amountB) {
        require(balanceOf[msg.sender] >= liquidity, "Insufficient liquidity balance");
        require(liquidity <= totalSupply, "Invalid liquidity amount");

        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        require(amountA >= amountAMin, "Insufficient A amount");
        require(amountB >= amountBMin, "Insufficient B amount");

        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.safeTransfer(to, amountA);
        tokenB.safeTransfer(to, amountB);

        emit Burn(to, liquidity, amountA, amountB);
        emit Sync(reserveA, reserveB);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address to
    ) external nonReentrant validAddress(to) validAmount(amountIn) returns (uint256 amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        require(amountOutMin > 0, "Invalid minimum output amount");

        bool isTokenA = tokenIn == address(tokenA);
        (uint256 reserveIn, uint256 reserveOut) = isTokenA ? (reserveA, reserveB) : (reserveB, reserveA);
        
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
            tokenB.safeTransfer(to, amountOut);
            emit Swap(msg.sender, amountIn, 0, 0, amountOut);
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
            tokenA.safeTransfer(to, amountOut);
            emit Swap(msg.sender, 0, amountIn, amountOut, 0);
        }

        emit Sync(reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        require(amountIn > 0, "Invalid input amount");

        bool isTokenA = tokenIn == address(tokenA);
        (uint256 reserveIn, uint256 reserveOut) = isTokenA ? (reserveA, reserveB) : (reserveB, reserveA);
        
        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function _calculateLiquidityAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) private view returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _mint(address to) private returns (uint256 liquidity) {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        
        uint256 amountA = balanceA - reserveA;
        uint256 amountB = balanceB - reserveB;

        if (totalSupply == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            balanceOf[address(0)] = MINIMUM_LIQUIDITY;
            totalSupply = MINIMUM_LIQUIDITY;
        } else {
            liquidity = _min((amountA * totalSupply) / reserveA, (amountB * totalSupply) / reserveB);
        }

        balanceOf[to] += liquidity;
        totalSupply += liquidity;

        reserveA = balanceA;
        reserveB = balanceB;

        emit Mint(to, liquidity);
        emit Sync(reserveA, reserveB);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid amounts");
        
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        
        return numerator / denominator;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
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

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x < y ? x : y;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }
}