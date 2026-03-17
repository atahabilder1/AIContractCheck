// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDEX {
    mapping(address => uint) public balances;

    function addLiquidity(uint amount) public {
        require(amount > 0, "Amount must be greater than zero");
        balances[msg.sender] += amount;
    }

    function swap(uint inputAmount, address tokenAddress) public {
        uint outputAmount = (inputAmount * balances[tokenAddress]) / balances[msg.sender];
        require(outputAmount > 0, "Swap would result in zero or less tokens");
        balances[msg.sender] -= inputAmount;
        balances[tokenAddress] += inputAmount;
    }
}