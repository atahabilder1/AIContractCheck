// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IFlashBorrower {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external;
}

contract FlashLoanProvider {
    address public immutable token;

    constructor(address _token) {
        token = _token;
    }

    function flashLoan(IFlashBorrower receiver, uint256 amount, bytes calldata data) external {
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        require(balBefore >= amount, "insufficient liquidity");

        require(IERC20(token).transfer(address(receiver), amount), "transfer out failed");

        receiver.onFlashLoan(msg.sender, token, amount, 0, data);

        require(IERC20(token).balanceOf(address(this)) >= balBefore, "not repaid");
    }
}