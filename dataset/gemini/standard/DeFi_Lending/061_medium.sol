```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingProtocol is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Market {
        IERC20 asset;
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 interestRate; // Percentage per second
        uint256 lastInterestAccrual;
        uint256 reserveFactor; // Percentage of interest to reserve
    }

    struct UserAccount {
        uint256 depositedAssetId;
        uint256 borrowedAssetId;
        uint256 depositAmount;
        uint256 borrowAmount;
        uint256 lastAccrualTime;
    }

    mapping(uint256 => Market) public markets;
    uint256 public marketCount;

    mapping(address => mapping(uint256 => UserAccount)) public userAccounts;
    mapping(address => bool) public whitelistedAssets;

    uint256 public constant HEALTH_FACTOR_THRESHOLD = 1e18; // 1.0 as a health factor
    uint256 public constant LIQUIDATION_THRESHOLD_FACTOR = 1.2e18; // 1.2x the borrowed amount for liquidation

    event MarketCreated(uint256 marketId, address asset, uint256 reserveFactor);
    event Deposited(address user, uint256 marketId, uint256 amount);
    event Withdrawn(address user, uint256 marketId, uint256 amount);
    event Borrowed(address user, uint256 marketId, uint256 amount);
    event Repaid(address user, uint256 marketId, uint256 amount);
    event Liquidation(address liquidator, address borrower, uint256 debtMarketId, uint256 collateralMarketId, uint256 debtAmount, uint256 collateralAmount);

    modifier onlyWhitelistedAsset(uint256 _marketId) {
        require(whitelistedAssets[address(markets[_marketId].asset)], "Asset not whitelisted");
        _;
    }

    function createMarket(address _asset, uint256 _reserveFactor) external onlyOwner {
        require(_asset != address(0), "Invalid asset address");
        require(_reserveFactor <= 1e18, "Reserve factor too high"); // Max 100%

        uint256 newMarketId = marketCount++;
        markets[newMarketId] = Market({
            asset: IERC20(_asset),
            totalDeposits: 0,
            totalBorrows: 0,
            interestRate: 0, // Initial interest rate can be set later or dynamically
            lastInterestAccrual: block.timestamp,
            reserveFactor: _reserveFactor
        });
        whitelistedAssets[_asset] = true;
        emit MarketCreated(newMarketId, _asset, _reserveFactor);
    }

    function setInterestRate(uint256 _marketId, uint256 _interestRate) external onlyOwner onlyWhitelistedAsset(_marketId) {
        require(_interestRate <= 1e18, "Interest rate too high"); // Max 100% per second (unrealistic, but for example)
        _accrueInterest(_marketId);
        markets[_marketId].interestRate = _interestRate;
    }

    function setReserveFactor(uint256 _marketId, uint256 _reserveFactor) external onlyOwner onlyWhitelistedAsset(_marketId) {
        require(_reserveFactor <= 1e18, "Reserve factor too high");
        _accrueInterest(_marketId);
        markets[_marketId].reserveFactor = _reserveFactor;
    }

    function deposit(uint256 _marketId, uint256 _amount) external nonReentrant onlyWhitelistedAsset(_marketId) {
        require(_amount > 0, "Deposit amount must be positive");

        UserAccount storage account = userAccounts[msg.sender][_marketId];
        if (account.depositAmount == 0) {
            account.depositedAssetId = _marketId;
        }
        require(account.depositedAssetId == _marketId, "User already deposited a different asset in this market");

        _accrueInterest(_marketId);
        markets[_marketId].asset.safeTransferFrom(msg.sender, address(this), _amount);
        markets[_marketId].totalDeposits += _amount;
        account.depositAmount += _amount;
        account.lastAccrualTime = block.timestamp;

        emit Deposited(msg.sender, _marketId, _amount);
    }

    function withdraw(uint256 _marketId, uint256 _amount) external nonReentrant onlyWhitelistedAsset(_marketId) {
        require(_amount > 0, "Withdraw amount must be positive");

        UserAccount storage account = userAccounts[msg.sender][_marketId];
        require(account.depositAmount >= _amount, "Insufficient deposit balance");

        _accrueInterest(_marketId);

        // Check if withdrawing this amount would make the user's health factor too low
        uint256 potentialDepositAmount = account.depositAmount - _amount;
        uint256 currentBorrowAmount = account.borrowAmount;
        uint256 healthFactor = _calculateHealthFactor(potentialDepositAmount, currentBorrowAmount, _marketId);
        require(healthFactor >= HEALTH_FACTOR_THRESHOLD, "Withdrawal would make health factor too low");

        markets[_marketId].totalDeposits -= _amount;
        account.depositAmount -= _amount;
        account.lastAccrualTime = block.timestamp;

        markets[_marketId].asset.safeTransfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _marketId, _amount);
    }

    function borrow(uint256 _marketId, uint256 _amount) external nonReentrant onlyWhitelistedAsset(_marketId) {
        require(_amount > 0, "Borrow amount must be positive");

        UserAccount storage account = userAccounts[msg.sender][_marketId];
        require(account.depositedAssetId != 0, "User has no deposits to collateralize");

        uint256 collateralDepositAmount = 0;
        uint256 collateralMarketId = account.depositedAssetId;
        collateralDepositAmount = userAccounts[msg.sender][collateralMarketId].depositAmount;

        require(collateralDepositAmount > 0, "User has no collateral");

        // Calculate health factor with the new borrow amount
        uint256 potentialBorrowAmount = account.borrowAmount + _amount;
        uint256 healthFactor = _calculateHealthFactor(collateralDepositAmount, potentialBorrowAmount, collateralMarketId);
        require(healthFactor >= HEALTH_FACTOR_THRESHOLD, "Borrowing this amount would make health factor too low");

        require(markets[_marketId].totalBorrows + _amount <= markets[_marketId].totalDeposits, "Insufficient liquidity to borrow");

        _accrueInterest(_marketId);
        markets[_marketId].totalBorrows += _amount;
        account.borrowAmount += _amount;
        account.borrowedAssetId = _marketId;
        account.lastAccrualTime = block.timestamp;

        markets[_marketId].asset.safeTransfer(msg.sender, _amount);

        emit Borrowed(msg.sender, _marketId, _amount);
    }

    function repay(uint256 _marketId, uint256 _amount) external nonReentrant onlyWhitelistedAsset(_marketId) {
        require(_amount > 0, "Repay amount must be positive");

        UserAccount storage account = userAccounts[msg.sender][_marketId];
        require(account.borrowAmount > 0, "User has no active borrow in this market");
        require(account.borrowedAssetId == _marketId, "User borrowed a different asset in this market");
        require(account.borrowAmount >= _amount, "Repay amount exceeds borrow amount");

        _accrueInterest(_marketId);

        uint256 interestOwed = _calculateInterestOwed(account.borrowAmount, account.lastAccrualTime, _marketId);
        uint256 totalDebt = account.borrowAmount + interestOwed;
        uint256 repayAmount = _amount > totalDebt ? totalDebt : _amount;

        markets[_marketId].totalBorrows -= repayAmount;
        account.borrowAmount -= repayAmount;
        account.lastAccrualTime = block.timestamp;

        markets[_marketId].asset.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repaid(msg.sender, _marketId, repayAmount);

        // If the debt is fully repaid, reset borrow-related fields
        if (account.borrowAmount == 0) {
            account.borrowedAssetId = 0;
            account.lastAccrualTime = block.timestamp; // Reset accrual time for future borrows
        }
    }

    function liquidate(address _borrower, uint256 _debtMarketId) external nonReentrant {
        require(whitelistedAssets[address(markets[_debtMarketId].asset)], "Debt asset not whitelisted");

        UserAccount storage borrowerAccount = userAccounts[_borrower][_debtMarketId];
        require(borrowerAccount.borrowAmount > 0, "Borrower has no debt in this market");

        uint256 collateralMarketId = borrowerAccount.depositedAssetId;
        require(collateralMarketId != 0, "Borrower has no collateral");
        require(whitelistedAssets[address(markets[collateralMarketId].asset)], "Collateral asset not whitelisted");

        uint256 borrowerCollateralAmount = userAccounts[_borrower][collateralMarketId].depositAmount;
        require(borrowerCollateralAmount > 0, "Borrower has no collateral");

        uint256 healthFactor = _calculateHealthFactor(borrowerCollateralAmount, borrowerAccount.borrowAmount, _debtMarketId);
        require(healthFactor < HEALTH_FACTOR_THRESHOLD, "Borrower's health factor is healthy, cannot liquidate");

        // Calculate the amount of debt to be liquidated
        uint256 debtToLiquidate = _getLiquidationAmount(borrowerCollateralAmount, borrowerAccount.borrowAmount, _debtMarketId, collateralMarketId);
        uint256 actualDebtToLiquidate = debtToLiquidate > borrowerAccount.borrowAmount ? borrowerAccount.borrowAmount : debtToLiquidate;

        // Calculate the amount of collateral to seize
        uint256 collateralToSeize = _getCollateralToSeize(actualDebtToLiquidate, borrowerCollateralAmount, _debtMarketId, collateralMarketId);
        collateralToSeize = collateralToSeize > borrowerCollateralAmount ? borrowerCollateralAmount : collateralToSeize;

        // Ensure we don't try to seize more than available or more than needed to cover debt
        require(collateralToSeize > 0, "No collateral to seize");
        require(actualDebtToLiquidate > 0, "No debt to liquidate");

        // Update borrower's account
        _accrueInterest(_debtMarketId);
        borrowerAccount.borrowAmount -= actualDebtToLiquidate;
        userAccounts[_borrower][collateralMarketId].depositAmount -= collateralToSeize;

        // Update market totals
        markets[_debtMarketId].totalBorrows -= actualDebtToLiquidate;
        markets[collateralMarketId].totalDeposits -= collateralToSeize;

        // Transfer debt from borrower to liquidator (conceptually, liquidator repays the protocol)
        // In a real protocol, the liquidator would pay the protocol for the seized collateral.
        // Here, we simplify by reducing the borrower's debt and transferring collateral.
        markets[_debtMarketId].asset.safeTransfer(msg.sender, actualDebtToLiquidate); // Transfer debt token to liquidator
        markets[collateralMarketId].asset.safeTransfer(msg.sender, collateralToSeize); // Transfer collateral to liquidator

        // Update last accrual times
        borrowerAccount.lastAccrualTime = block.timestamp;
        userAccounts[_borrower][collateralMarketId].lastAccrualTime = block.timestamp;

        emit Liquidation(msg.sender, _borrower, _debtMarketId, collateralMarketId, actualDebtToLiquidate, collateralToSeize);
    }

    function _accrueInterest(uint256 _marketId) internal {
        Market storage market = markets[_marketId];
        if (market.totalBorrows > 0 && market.interestRate > 0) {
            uint256 timeElapsed = block.timestamp - market.lastInterestAccrual;
            if (timeElapsed > 0) {
                // Calculate interest for the elapsed time
                // interest = principal * rate * time
                // Using fixed-point arithmetic for precision
                uint256 interest = (market.totalBorrows * market.interestRate * timeElapsed) / 1e18; // Assuming interestRate is 1e18 for 100% per second (for example)

                // Calculate reserves
                uint256 reserves = (interest * market.reserveFactor) / 1e18;

                // Add interest to total borrows
                market.totalBorrows += interest;

                // Add reserves to a separate reserve pool (not implemented in this simplified version)
                // For now, we just reduce the interest by the reserve factor
                market.totalBorrows -= reserves;

                market.lastInterestAccrual = block.timestamp;
            }
        }
    }

    function _calculateInterestOwed(uint256 _principal, uint256 _lastAccrualTime, uint256 _marketId) internal view returns (uint256) {
        Market storage market = markets[_marketId];
        if (_principal == 0 || market.interestRate == 0) {
            return 0;
        }
        uint256 timeElapsed = block.timestamp > _lastAccrualTime ? block.timestamp - _lastAccrualTime : 0;
        return (_principal * market.interestRate * timeElapsed) / 1e18;
    }

    function _calculateHealthFactor(uint256 _depositAmount, uint256 _borrowAmount, uint256 _borrowMarketId) internal view returns (uint256) {
        if (_borrowAmount == 0) {
            return type(uint256).max; // Infinite health if no debt
        }

        // This is a simplified health factor calculation.
        // In a real protocol, this would involve collateralization ratios and asset prices.
        // For this example, we'll assume a direct ratio of deposited asset value to borrowed asset value.
        // This requires an oracle for asset prices. For simplicity, we'll assume 1:1 value.

        // Let's assume we have a function `_getAssetValue(uint256 _amount, uint256 _marketId)`
        // that returns the value of an asset in a common base currency (e.g., USD).
        // For this example, we'll omit the oracle and assume a 1:1 value for simplicity.

        uint256 depositValue = _depositAmount; // Assuming 1:1 value
        uint256 borrowValue = _borrowAmount;   // Assuming 1:1 value

        // Health Factor = (Deposit Value * Collateralization Ratio) / Borrow Value
        // We need collateralization ratios for each asset. This is a missing piece.
        // For now, let's use a simple ratio and the liquidation threshold.

        // A common health factor formula is:
        // HF = (Total Collateral Value) / (Total Borrowed Value)
        // Where collateral value is deposit amount * price * collateral_factor
        // And borrowed value is borrow amount * price

        // Let's assume a fixed collateralization ratio of 1.5x for simplicity (meaning 150% collateral)
        // This means for every $1 borrowed, you need $1.5 in collateral.
        // Health Factor = (Deposit Amount * 1.5) / Borrow Amount

        uint256 collateralizationRatio = 1.5e18; // 1.5x
        uint256 numerator = depositValue * collateralizationRatio;
        uint256 denominator = borrowValue;

        if (denominator == 0) {
            return type(uint256).max;
        }

        return (numerator * 1e18) / denominator; // Scale to maintain precision
    }

    function _getLiquidationAmount(uint256 _depositAmount, uint256 _borrowAmount, uint256 _debtMarketId, uint256 _collateralMarketId) internal view returns (uint256) {
        // Calculate how much debt can be liquidated based on the collateralization threshold.
        // The liquidation threshold determines the maximum borrowable amount for a given collateral.
        // If borrowAmount > (depositAmount * liquidationThresholdFactor) / 1e18, liquidation is triggered.