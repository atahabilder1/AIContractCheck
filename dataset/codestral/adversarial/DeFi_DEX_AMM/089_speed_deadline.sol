// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DefiDEX {
    mapping(address => uint) public balances;
    mapping(address => mapping (address => uint)) public reserves;

    function addLiquidity(uint amountToken, address tokenAddress) external {
        require(amountToken > 0, "Amount should be greater than zero");
        balances[msg.sender] += amountToken;
        msg.sender.transferFrom(tokenAddress, address(this), amountToken);
        reserves[address(this)][tokenAddress] += amountToken;
    }

    function swapTokens(uint inputAmount, address inputToken, address outputToken) external {
        require(inputAmount > 0, "Input amount should be greater than zero");
        uint liquidity = balances[msg.sender];
        uint inputReserve = reserves[address(this)][inputToken];
        uint outputReserve = reserves[address(this)][outputToken];

        require(liquidity > 0 && inputReserve > 0 && outputReserve > 0, "Insufficient liquidity");

        uint inputAmountWithFee = inputAmount * 997;
        uint outputAmount = inputAmountWithFee * outputReserve / (inputReserve + inputAmountWithFee);

        balances[msg.sender] -= inputAmount;
        reserves[address(this)][inputToken] += inputAmount;
        msg.sender.transferFrom(inputToken, address(this), inputAmount);

        msg.sender.transfer(outputAmount);
        IERC20(outputToken).transfer(msg.sender, outputAmount);
        reserves[address(this)][outputToken] -= outputAmount;
    }
}