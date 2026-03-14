// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CollateralizedLending is ReentrancyGuard {
    IERC20 public stablecoin;
    mapping(address => uint256) public collaterals;
    mapping(address => uint256) public debts;
    uint256 public collateralRatio;

    constructor(IERC20 _stablecoin, uint256 _collateralRatio) {
        stablecoin = _stablecoin;
        collateralRatio = _collateralRatio;
    }

    function depositCollateral() external payable {
        require(msg.value > 0, "Deposit must be greater than zero");
        collaterals[msg.sender] += msg.value;
    }

    function borrowStablecoin(uint256 amount) external nonReentrant {
        require(amount > 0, "Borrow amount must be greater than zero");
        require(collaterals[msg.sender] >= amount * collateralRatio, "Collateral must be at least collateral ratio times the borrow amount");
        require(stablecoin.balanceOf(address(this)) >= amount, "Contract does not have enough stablecoin to borrow");

        collaterals[msg.sender] -= amount * collateralRatio;
        debts[msg.sender] += amount;
        stablecoin.transfer(msg.sender, amount);
    }

    function repayStablecoin(uint256 amount) external nonReentrant {
        require(amount > 0, "Repay amount must be greater than zero");
        require(debts[msg.sender] >= amount, "Repay amount must be less than or equal to the debt");

        debts[msg.sender] -= amount;
        stablecoin.transferFrom(msg.sender, address(this), amount);
    }

    function liquidate(address borrower) external nonReentrant {
        require(collaterals[borrower] < debts[borrower] * collateralRatio, "Collateral must be less than debt times collateral ratio");

        uint256 amountToRepay = debts[borrower];
        debts[borrower] = 0;
        stablecoin.transferFrom(msg.sender, borrower, amountToRepay);
    }
}