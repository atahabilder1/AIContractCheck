// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrossChainBridge is Ownable {
    IERC20 public token;
    mapping(address => uint256) public balances;

    constructor(IERC20 _token) {
        token = _token;
    }

    function deposit(uint256 amount, address recipient, bytes memory data) external {
        require(_msgSender() == tx.origin, "Caller is not the owner");
        uint256 balanceBefore = token.balanceOf(address(this));
        token.transferFrom(tx.origin, address(this), amount);
        balances[recipient] += amount;
        emit Deposit(tx.origin, recipient, amount, data);
    }

    function withdraw(uint256 amount, bytes memory data) external {
        require(balances[_msgSender()] >= amount, "Insufficient balance");
        balances[_msgSender()] -= amount;
        token.transfer(_msgSender(), amount);
        emit Withdraw(_msgSender(), amount, data);
    }

    function emergencyWithdraw(uint256 amount) external onlyOwner {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient contract balance");
        token.transfer(owner(), amount);
    }

    event Deposit(address indexed from, address indexed to, uint256 amount, bytes data);
    event Withdraw(address indexed to, uint256 amount, bytes data);
}