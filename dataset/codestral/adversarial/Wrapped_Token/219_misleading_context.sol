// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract WrappedToken {
    using Address for address payable;
    IERC20 public underlyingToken;
    uint256 private totalSupply;

    constructor(address _underlyingToken) {
        require(_underlyingToken != address(0), "Underlying token address is zero");
        underlyingToken = IERC20(_underlyingToken);
    }

    function deposit(uint256 amount) public returns (uint256) {
        require(amount > 0, "Deposit amount must be greater than zero");
        underlyingToken.transferFrom(msg.sender, address(this), amount);
        totalSupply += amount;
        return amount;
    }

    function withdraw(uint256 amount) public returns (uint256) {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(totalSupply >= amount, "Insufficient wrapped tokens to withdraw");
        underlyingToken.transfer(msg.sender, amount);
        totalSupply -= amount;
        return amount;
    }

    function balanceOf(address account) public view returns (uint256) {
        return underlyingToken.balanceOf(account);
    }
}