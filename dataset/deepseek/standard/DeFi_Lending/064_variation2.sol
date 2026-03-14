// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LendingPool is Ownable {
    using SafeMath for uint256;

    struct Market {
        uint256 totalCollateral;
        uint256 totalBorrowed;
        uint256 liquidationThreshold;
        uint256 liquidationRatio;
        uint256 borrowRate;
    }

    mapping(address => Market) public markets;

    function addMarket(
        address collateralToken,
        uint256 liquidationThreshold,
        uint256 liquidationRatio,
        uint256 borrowRate
    ) external onlyOwner {
        require(liquidationThreshold > 0, "Liquidation threshold must be greater than zero");
        require(liquidationRatio > 0, "Liquidation ratio must be greater than zero");
        require(borrowRate > 0, "Borrow rate must be greater than zero");

        markets[collateralToken] = Market({
            totalCollateral: 0,
            totalBorrowed: 0,
            liquidationThreshold: liquidationThreshold,
            liquidationRatio: liquidationRatio,
            borrowRate: borrowRate
        });
    }

    function depositCollateral(address collateralToken, uint256 amount) external {
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        markets[collateralToken].totalCollateral += amount;
    }

    function borrow(address collateralToken, uint256 amount) external {
        Market storage market = markets[collateralToken];
        require(market.totalCollateral > 0, "No market exists for this collateral token");
        require(market.totalBorrowed.add(amount) <= market.totalCollateral.mul(market.liquidationThreshold).div(100), "Borrow amount exceeds collateral value");

        market.totalBorrowed += amount;
        IERC20(collateralToken).transfer(msg.sender, amount);
    }

    function repay(address collateralToken, uint256 amount) external {
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        markets[collateralToken].totalBorrowed -= amount;
    }

    function liquidate(address collateralToken, address borrower, uint256 amountToRepay) external {
        Market storage market = markets[collateralToken];
        require(market.totalBorrowed > 0, "No outstanding borrow for this collateral token");
        require(amountToRepay <= market.totalBorrowed, "Repay amount exceeds outstanding borrow");

        uint256 liquidationRatioInEffect = market.totalBorrowed.mul(market.liquidationRatio).div(100);
        uint256 collateralValue = market.totalCollateral.mul(market.liquidationThreshold).div(100);
        require(liquidationRatioInEffect > collateralValue, "Collateral value does not meet liquidation requirements");

        uint256 liquidatedAmount = amountToRepay.mul(collateralValue).div(market.totalBorrowed);
        IERC20(collateralToken).transfer(borrower, liquidatedAmount);
        market.totalBorrowed -= amountToRepay;
    }
}