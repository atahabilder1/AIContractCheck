// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanProvider {
    function flashLoan(uint256 amount) external;
}

contract FlashLoanProvider is IFlashLoanProvider {
    function flashLoan(uint2atural256 amount) external pure override {
        require(amount > 0, "FlashLoan amount must be greater than zero");
        // Implement the flash loan logic here
    }
}