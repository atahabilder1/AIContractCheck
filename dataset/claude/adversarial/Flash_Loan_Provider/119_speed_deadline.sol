// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external returns (bool);
}

contract FlashLoanProvider is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public feeBasisPoints = 9; // 0.09%
    uint256 private constant BASIS_POINTS = 10000;

    mapping(address => uint256) public liquidityDeposits;
    mapping(address => mapping(address => uint256)) public depositorBalances;

    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);
    event Deposited(address indexed depositor, address indexed token, uint256 amount);
    event Withdrawn(address indexed depositor, address indexed token, uint256 amount);
    event FeeUpdated(uint256 newFeeBasisPoints);

    constructor() Ownable(msg.sender) {}

    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        depositorBalances[msg.sender][token] += amount;
        liquidityDeposits[token] += amount;
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        require(depositorBalances[msg.sender][token] >= amount, "Insufficient balance");
        depositorBalances[msg.sender][token] -= amount;
        liquidityDeposits[token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata params
    ) external nonReentrant {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        uint256 fee = (amount * feeBasisPoints) / BASIS_POINTS;

        IERC20(token).safeTransfer(receiver, amount);

        require(
            IFlashLoanReceiver(receiver).executeOperation(token, amount, fee, params),
            "Flash loan execution failed"
        );

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid");

        emit FlashLoan(receiver, token, amount, fee);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(uint256 amount) external view returns (uint256) {
        return (amount * feeBasisPoints) / BASIS_POINTS;
    }

    function setFeeBasisPoints(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee too high"); // max 1%
        feeBasisPoints = newFee;
        emit FeeUpdated(newFee);
    }

    function withdrawFees(address token, uint256 amount) external onlyOwner {
        uint256 available = IERC20(token).balanceOf(address(this)) - liquidityDeposits[token];
        require(amount <= available, "Exceeds collected fees");
        IERC20(token).safeTransfer(owner(), amount);
    }
}