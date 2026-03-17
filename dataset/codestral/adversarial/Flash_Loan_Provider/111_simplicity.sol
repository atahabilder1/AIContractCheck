// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashLoanProvider {
    IERC20 public token;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function flashLoan(uint amount, address recipient) external {
        require(amount > 0, "Amount must be greater than zero");

        uint balanceBefore = token.balanceOf(address(this));
        uint recipientBalanceBefore = token.balanceOf(recipient);

        token.transferFrom(msg.sender, address(this), amount);
        token.transfer(recipient, amount);

        // Call the flash loan receiver contract here

        require(token.balanceOf(address(this)) == balanceBefore + amount, "Tokens were not returned");
        require(token.balanceOf(recipient) == recipientBalanceBefore, "Recipient's balance changed unexpectedly");
    }
}