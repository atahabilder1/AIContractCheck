// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanReceiver {
    function executeFlashLoan(uint256 amount) external;
}

contract FlashLoanProvider {
    function flashLoan(IFlashLoanReceiver receiver, uint256 amount) external {
        receiver.executeFlashLoan(amount);
    }
}