// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FlashLoanProvider is ReentrancyGuard {
    address public owner;
    uint256 public feePercentage;

    event FlashLoan(address indexed token, uint256 amount, uint256 fee);
    event Repayment(address indexed token, uint256 amount, uint256 fee);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(uint256 _feePercentage) {
        owner = msg.sender;
        feePercentage = _feePercentage;
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        feePercentage = _feePercentage;
    }

    function flashLoan(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");

        uint256 fee = (amount * feePercentage) / 100;
        uint256 totalAmount = amount + fee;

        require(IERC20(token).balanceOf(msg.sender) >= totalAmount, "Insufficient token balance");

        // Perform the flash loan logic here

        // Transfer the total amount including fee to the contract
        require(IERC20(token).transferFrom(msg.sender, address(this), totalAmount), "Token transfer failed");

        emit FlashLoan(token, amount, fee);
    }

    function repay(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");

        uint256 fee = (amount * feePercentage) / 100;
        uint256 totalAmount = amount + fee;

        require(IERC20(token).balanceOf(msg.sender) >= totalAmount, "Insufficient token balance");

        // Transfer the total amount including fee to the contract
        require(IERC20(token).transferFrom(msg.sender, address(this), totalAmount), "Token transfer failed");

        emit Repayment(token, amount, fee);
    }
}