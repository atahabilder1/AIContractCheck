// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(uint256 amount, uint256 fee, address initiator, bytes calldata params) external;
}

contract FlashLoanProvider {
    IERC20 public immutable token;
    uint256 public constant FEE_PERCENTAGE = 1; // 0.01%

    constructor(address _token) {
        token = IERC20(_token);
    }

    function flashLoan(uint256 amount, address receiver, bytes calldata params) external {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        uint256 fee = (amount * FEE_PERCENTAGE) / 10000;
        require(token.transfer(receiver, amount), "Transfer failed");

        IFlashLoanReceiver(receiver).executeOperation(amount, fee, msg.sender, params);

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Loan not repaid with fee");

        if (balanceAfter > balanceBefore + fee) {
            token.transfer(receiver, balanceAfter - balanceBefore - fee); // Return excess balance
        }
    }
}