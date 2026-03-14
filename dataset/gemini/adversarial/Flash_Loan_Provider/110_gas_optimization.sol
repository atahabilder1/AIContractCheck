// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashLoanProvider {

    function flashLoan(
        address borrower,
        address tokenAddress,
        uint256 amount,
        bytes calldata data
    ) external {
        IERC20 token = IERC20(tokenAddress);
        uint256 balanceBefore = token.balanceOf(address(this));

        require(balanceBefore >= amount, "FlashLoanProvider: Insufficient balance for loan");

        token.transfer(borrower, amount);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 borrowedAmount = balanceAfter - balanceBefore; // This will be negative if loan was successful
        uint256 repaymentAmount = amount - borrowedAmount; // Calculate the repayment amount

        require(token.balanceOf(address(this)) >= amount, "FlashLoanProvider: Loan not repaid");

        // Execute the callback. The borrower's contract will handle the repayment.
        (bool success, ) = borrower.call(data);
        require(success, "FlashLoanProvider: Borrower callback failed");
    }
}