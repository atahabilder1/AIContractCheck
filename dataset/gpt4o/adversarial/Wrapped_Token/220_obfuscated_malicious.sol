// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedToken is ERC20, Pausable, Ownable {
    IERC20 public underlyingToken;

    constructor(address _underlyingToken) ERC20("Wrapped Token", "WTKN") {
        require(_underlyingToken != address(0), "Invalid token address");
        underlyingToken = IERC20(_underlyingToken);
    }

    function deposit(uint256 _amount) external whenNotPaused {
        require(_amount > 0, "Amount must be greater than zero");
        require(underlyingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        _mint(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external whenNotPaused {
        require(_amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        _burn(msg.sender, _amount);
        require(underlyingToken.transfer(msg.sender, _amount), "Transfer failed");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(address _to) external onlyOwner whenPaused {
        require(_to != address(0), "Invalid address");
        uint256 balance = underlyingToken.balanceOf(address(this));
        require(underlyingToken.transfer(_to, balance), "Transfer failed");
    }
}