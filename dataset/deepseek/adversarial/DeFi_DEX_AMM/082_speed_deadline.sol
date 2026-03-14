// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Dex is Ownable {
    struct Token {
        bool isListed;
        address tokenAddress;
    }

    mapping(address => Token) public tokens;
    address[] public tokenList;

    event TokenAdded(address indexed tokenAddress);
    event TokenRemoved(address indexed tokenAddress);
    event TokenSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    function addToken(address tokenAddress) public onlyOwner {
        require(!tokens[tokenAddress].isListed, "Token already listed");
        tokens[tokenAddress] = Token({isListed: true, tokenAddress: tokenAddress});
        tokenList.push(tokenAddress);
        emit TokenAdded(tokenAddress);
    }

    function removeToken(address tokenAddress) public onlyOwner {
        require(tokens[tokenAddress].isListed, "Token not listed");
        tokens[tokenAddress].isListed = false;
        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == tokenAddress) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
        emit TokenRemoved(tokenAddress);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) public {
        require(tokens[tokenIn].isListed, "Token not listed");
        require(tokens[tokenOut].isListed, "Token not listed");
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        uint256 reserveIn = IERC20(tokenIn).balanceOf(address(this));
        uint256 reserveOut = IERC20(tokenOut).balanceOf(address(this));
        uint256 amountOut = (amountIn * reserveOut) / reserveIn;
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut);
    }
}