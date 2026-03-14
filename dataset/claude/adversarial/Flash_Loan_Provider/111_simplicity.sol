// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanReceiver {
    function executeOperation(address token, uint256 amount, uint256 fee, bytes calldata params) external;
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FlashLoanProvider {
    uint256 public constant FEE_BPS = 9; // 0.09%
    address public owner;

    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);

    constructor() {
        owner = msg.sender;
    }

    function deposit(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address token, uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        IERC20(token).transfer(msg.sender, amount);
    }

    function flashLoan(address token, uint256 amount, bytes calldata params) external {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        uint256 fee = (amount * FEE_BPS) / 10000;

        IERC20(token).transfer(msg.sender, amount);

        IFlashLoanReceiver(msg.sender).executeOperation(token, amount, fee, params);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Loan not repaid");

        emit FlashLoan(msg.sender, token, amount, fee);
    }
}