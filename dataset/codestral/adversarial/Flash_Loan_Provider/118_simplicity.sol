// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC20/IERC20.sol";

contract FlashLoanProvider {
    IERC20 public token;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function flashLoan(uint amount, address borrower, bytes memory data) external {
        uint balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= amount, "Not enough tokens in the pool");

        token.transfer(borrower, amount);

        IERC20(msg.sender).transferFrom(borrower, address(this), amount);

        uint balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }
}