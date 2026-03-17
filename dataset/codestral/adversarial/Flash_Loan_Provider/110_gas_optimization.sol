// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IFlashLoanReceiver.sol";

interface IFlashLoanProvider {
    function flashLoan(address token, uint amount) external;
}

contract FlashLoanProvider is IFlashLoanProvider {
    mapping(address => IERC20) private tokens;

    constructor() {}

    function flashLoan(address token, uint amount) external override {
        require(_isTokenSupported(token), "Unsupported token");
        IERC20 tokenInstance = tokens[token];
        uint balanceBefore = tokenInstance.balanceOf(address(this));

        _beforeFlashLoan(token);
        tokenInstance.transferFrom(msg.sender, address(this), amount);
        IFlashLoanReceiver(msg.sender).onFlashLoan(token, amount);
        uint balanceAfter = tokenInstance.balanceOf(address(this));
        require(balanceBefore == balanceAfter, "Incorrect flash loan implementation");
    }

    function _beforeFlashLoan(address) internal virtual {}

    function addToken(address token) external {
        require(_isTokenSupported(token) == false, "Token already supported");
        tokens[token] = IERC20(token);
    }

    function _isTokenSupported(address token) private view returns (bool) {
        return tokens[token] != address(0);
    }
}