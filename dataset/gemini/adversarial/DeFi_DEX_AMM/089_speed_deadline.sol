// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SimpleDEX is Ownable {
    using SafeMath for uint256;

    mapping(address => mapping(address => uint256)) public reserves; // tokenA => tokenB => reserveAmount
    mapping(address => mapping(address => address)) public tokenPairs; // tokenA => tokenB => pairAddress

    event PairCreated(address indexed tokenA, address indexed tokenB, address indexed pairAddress);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Swap(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    constructor() {
        // The zero address can represent ETH, but for this simple example, we'll assume only ERC20 tokens.
        // If you need ETH support, you'll need to handle native transfers and use a placeholder like address(0).
    }

    function createPair(address tokenA, address tokenB) public onlyOwner {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(tokenA != tokenB, "Tokens cannot be the same");

        // Ensure consistent ordering for pair mapping
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        require(tokenPairs[tokenA][tokenB] == address(0), "Pair already exists");

        // In a real DEX, this would deploy a new Pair contract.
        // For this demo, we'll simulate it by just setting up the reserve mapping.
        // A real Pair contract would manage liquidity, trading, and fees.
        // We'll use a placeholder address for the pair, or you could deploy a minimal Pair contract.
        // For this *very* simple demo, we'll just use the token addresses themselves to identify a "pair".
        // This is highly simplified and not how a real DEX works.
        // A real DEX would have a separate `Pair` contract for each token pair.

        // For this demo, we'll just store the reserve amounts directly in the DEX contract.
        // This is NOT how a real AMM works. A real AMM has a separate Pair contract.
        // We are simulating the *concept* of reserves for a pair here.
        // The `tokenPairs` mapping is conceptually where the pair address would be stored.
        // We won't deploy a pair contract for this minimal demo.

        tokenPairs[tokenA][tokenB] = address(1); // Placeholder for a pair, not a real deployed contract address

        emit PairCreated(tokenA, tokenB, address(1)); // Emitting placeholder pair address
    }

    function _getPair(address tokenA, address tokenB) internal view returns (address pairPlaceholder) {
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        pairPlaceholder = tokenPairs[tokenA][tokenB];
        require(pairPlaceholder != address(0), "Pair does not exist");
        return pairPlaceholder;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) public {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(amountA > 0 || amountB > 0, "Amount must be positive");

        // Ensure consistent ordering
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }

        address pairPlaceholder = _getPair(tokenA, tokenB);

        // Transfer tokens from user to the DEX contract (simulating transfer to pair)
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        // Update reserves
        reserves[tokenA][tokenB] = reserves[tokenA][tokenB].add(amountA);
        reserves[tokenB][tokenA] = reserves[tokenB][tokenA].add(amountB);

        emit Deposit(msg.sender, tokenA, amountA);
        emit Deposit(msg.sender, tokenB, amountB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) public {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(amountA > 0 || amountB > 0, "Amount must be positive");

        // Ensure consistent ordering
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }

        address pairPlaceholder = _getPair(tokenA, tokenB);

        // Check if enough liquidity exists
        require(reserves[tokenA][tokenB] >= amountA, "Insufficient liquidity for tokenA");
        require(reserves[tokenB][tokenA] >= amountB, "Insufficient liquidity for tokenB");

        // Update reserves
        reserves[tokenA][tokenB] = reserves[tokenA][tokenB].sub(amountA);
        reserves[tokenB][tokenA] = reserves[tokenB][tokenA].sub(amountB);

        // Transfer tokens back to user
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit Withdraw(msg.sender, tokenA, amountA);
        emit Withdraw(msg.sender, tokenB, amountB);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) public {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid token address");
        require(amountIn > 0, "Amount must be positive");

        // Ensure consistent ordering for pair lookup
        address tokenA = tokenIn;
        address tokenB = tokenOut;
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        address pairPlaceholder = _getPair(tokenA, tokenB);

        // Transfer tokens from user to the DEX contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Calculate amount out using the AMM formula (x * y = k)
        // For simplicity, we'll use the reserves directly from this contract.
        // In a real DEX, you'd interact with the Pair contract.
        uint256 reserveIn = (tokenIn == tokenA) ? reserves[tokenA][tokenB] : reserves[tokenB][tokenA];
        uint256 reserveOut = (tokenOut == tokenA) ? reserves[tokenA][tokenB] : reserves[tokenB][tokenA];

        // Add a small fee (e.g., 0.3%)
        uint256 amountInWithFee = amountIn.mul(997); // 997/1000, equivalent to 0.3% fee
        uint256 amountOut = (reserveOut.mul(amountInWithFee)).div(reserveIn.add(amountInWithFee));

        require(amountOut > 0, "Swap failed: insufficient output amount");

        // Update reserves
        if (tokenIn == tokenA) {
            reserves[tokenA][tokenB] = reserves[tokenA][tokenB].add(amountIn);
        } else {
            reserves[tokenB][tokenA] = reserves[tokenB][tokenA].add(amountIn);
        }
        if (tokenOut == tokenA) {
            reserves[tokenA][tokenB] = reserves[tokenA][tokenB].sub(amountOut);
        } else {
            reserves[tokenB][tokenA] = reserves[tokenB][tokenA].sub(amountOut);
        }

        // Transfer tokens to user
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // Helper functions to view reserves (for demonstration)
    function getReserves(address tokenA, address tokenB) public view returns (uint256 reserveA, uint256 reserveB) {
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        reserveA = reserves[tokenA][tokenB];
        reserveB = reserves[tokenB][tokenA];
        return (reserveA, reserveB);
    }

    function getTokenPair(address tokenA, address tokenB) public view returns (address pairAddress) {
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        return tokenPairs[tokenA][tokenB];
    }
}