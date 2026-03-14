// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFlashLoanReceiver {
    function onFlashLoan(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

contract FlashLoanProvider is Ownable {
    using SafeERC20 for IERC20;

    uint256 public feeBps = 9; // 0.09%
    mapping(address => uint256) public reserves;

    event Deposit(address indexed token, address indexed depositor, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 newFeeBps);

    constructor() Ownable(msg.sender) {}

    function deposit(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        reserves[token] += amount;
        emit Deposit(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        require(reserves[token] >= amount, "Insufficient reserves");
        reserves[token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw(token, msg.sender, amount);
    }

    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Not enough liquidity");

        uint256 fee = (amount * feeBps) / 10000;

        IERC20(token).safeTransfer(msg.sender, amount);

        IFlashLoanReceiver(msg.sender).onFlashLoan(token, amount, fee, data);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid");

        reserves[token] += fee;

        emit FlashLoan(msg.sender, token, amount, fee);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Fee too high");
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function availableLiquidity(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}