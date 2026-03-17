// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashLoanProvider is Ownable {
    IERC20 public token;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function flashLoan(address borrower, uint256 amount) external returns (bool) {
        require(amount > 0, "Amount must be greater than zero");
        token.transferFrom(msg.sender, address(this), amount);
        // Call the borrower contract to execute the flash loan
        bool success = IFlashLoanBorrower(borrower).executeFlashLoan(amount);
        if (success) {
            token.transfer(msg.sender, amount);
            return true;
        } else {
            // If borrower fails to repay the loan, revert and keep the funds in the contract
            require(token.balanceOf(address(this)) >= amount, "Insufficient funds");
            return false;
        }
    }

    function withdrawAllFunds() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    function pauseOperations() external onlyOwner {
        // Implement pausable operations logic if required
    }

    function resumeOperations() external onlyOwner {
        // Implement resuming paused operations logic if required
    }
}

interface IFlashLoanBorrower {
    function executeFlashLoan(uint256 amount) external returns (bool);
}