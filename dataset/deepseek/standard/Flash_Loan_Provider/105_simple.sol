// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FlashLoan is ReentrancyGuard {
    IERC20 public token;
    uint256 public feeRate;

    event FlashLoan(address indexed borrower, uint256 amount);
    event FlashLoanRepayed(address indexed borrower, uint256 amount);

    constructor(address _token, uint256 _feeRate) {
        token = IERC20(_token);
        feeRate = _feeRate;
    }

    function flashLoan(uint256 amount) external nonReentrant {
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        token.transfer(msg.sender, amount);
        emit FlashLoan(msg.sender, amount);
    }

    function repayFlashLoan(uint256 amount) external nonReentrant {
        require(msg.sender == address(this), "Only this contract can repay the loan");
        uint256 fee = (amount * feeRate) / 10000;
        uint256 totalRepayment = amount + fee;
        require(token.balanceOf(address(this)) >= totalRepayment, "Insufficient balance to repay the loan");
        token.transferFrom(msg.sender, address(this), totalRepayment);
        emit FlashLoanRepayed(msg.sender, amount);
    }
}