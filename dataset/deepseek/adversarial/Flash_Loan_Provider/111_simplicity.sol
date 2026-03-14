// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanProvider {
    function flashLoan(address borrower, uint256 amount) external;
}

contract FlashLoanProvider is IFlashLoanProvider {
    function flashLoan(address borrower, uint256 amount) external override {
        // Logic for the flash loan
        // For simplicity, let's assume we just send the amount to the borrower
        (bool success, ) = borrower.call{value: amount}("");
        require(success, "FlashLoan: Transfer failed");
    }
}