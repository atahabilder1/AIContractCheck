// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract DefiDEX {
    mapping(address => uint) public reserves;
    address public tokenAddress;

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function addLiquidity(uint amount) external {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        reserves[msg.sender] += amount;
    }

    function removeLiquidity(uint amount) external {
        require(reserves[msg.sender] >= amount, "Insufficient liquidity");
        IERC20(tokenAddress).transfer(msg.sender, amount);
        reserves[msg.sender] -= amount;
    }

    function swapTokens(uint inputAmount) external {
        uint inputReserve = reserves[address(this)];
        uint outputReserve = IERC20(tokenAddress).balanceOf(address(this));
        uint numerator = inputAmount * outputReserve;
        uint denominator = inputReserve + inputAmount;
        uint outputAmount = numerator / denominator;

        require(outputAmount > 0, "Insufficient output amount");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), inputAmount);
        IERC20(tokenAddress).transfer(msg.sender, outputAmount);

        reserves[address(this)] += inputAmount;
        reserves[msg.sender] -= outputAmount;
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
}