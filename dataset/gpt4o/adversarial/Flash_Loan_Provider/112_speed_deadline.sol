// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(uint256 amount) external;
}

contract FlashLoanProvider {
    IERC20 public token;
    uint256 public fee = 1; // 0.1% fee

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function flashLoan(uint256 amount, address receiver) external {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        token.transfer(receiver, amount);
        IFlashLoanReceiver(receiver).executeOperation(amount);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 requiredRepayment = amount + (amount * fee / 1000);
        require(balanceAfter >= requiredRepayment, "Flash loan hasn't been repaid");

        token.transferFrom(receiver, address(this), requiredRepayment);
    }
}