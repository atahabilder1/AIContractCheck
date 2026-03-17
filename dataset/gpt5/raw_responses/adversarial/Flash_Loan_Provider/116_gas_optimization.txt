// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IFlashLoanReceiver {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external;
}

contract FlashLoanProvider {
    error NotEnoughLiquidity();
    error TransferFailed();
    error NotRepaid();
    error FeeTooHigh();

    IERC20 public immutable token;
    uint256 public immutable feeBps;

    constructor(IERC20 t, uint256 f) {
        if (f > 10000) revert FeeTooHigh();
        token = t;
        feeBps = f;
    }

    function flashLoan(address receiver, uint256 amount, bytes calldata data) external returns (bool) {
        uint256 bal = token.balanceOf(address(this));
        if (amount > bal) revert NotEnoughLiquidity();

        uint256 fee;
        unchecked {
            fee = (amount * feeBps) / 10000;
        }

        if (!token.transfer(receiver, amount)) revert TransferFailed();

        IFlashLoanReceiver(receiver).onFlashLoan(msg.sender, address(token), amount, fee, data);

        unchecked {
            if (token.balanceOf(address(this)) < bal + fee) revert NotRepaid();
        }

        return true;
    }
}