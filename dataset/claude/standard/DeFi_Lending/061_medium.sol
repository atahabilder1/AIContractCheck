// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingProtocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Asset {
        address tokenAddress;
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 baseRate;           // Base interest rate (in basis points, e.g., 200 = 2%)
        uint256 slopeRate;          // Rate slope (basis points)
        uint256 optimalUtilization; // Optimal utilization rate (basis points, e.g., 8000 = 80%)
        uint256 excessSlope;        // Slope above optimal utilization (basis points)
        uint256 liquidationThreshold; // e.g., 8000 = 80%
        uint256 liquidationBonus;     // e.g., 500 = 5%
        uint256 collateralFactor;     // e.g., 7500 = 75%
        uint256 lastUpdateTimestamp;
        uint256 borrowIndex;        // Cumulative borrow index (scaled by 1e18)
        uint256 price;              // Price in USD (scaled by 1e18)
        bool isActive;
    }

    struct UserPosition {
        uint256 depositAmount;
        uint256 borrowAmount;
        uint256 borrowIndex; // User's borrow index snapshot
    }

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant INDEX_PRECISION = 1e18;

    mapping(address => Asset) public assets;
    address[] public assetList;
    mapping(address => mapping(address => UserPosition)) public userPositions; // user => token => position

    event AssetAdded(address indexed token);
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed borrower,
        address indexed debtToken,
        address collateralToken,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event PriceUpdated(address indexed token, uint256 newPrice);

    constructor() Ownable() {}

    function addAsset(
        address _token,
        uint256 _baseRate,
        uint256 _slopeRate,
        uint256 _optimalUtilization,
        uint256 _excessSlope,
        uint256 _liquidationThreshold,
        uint256 _liquidationBonus,
        uint256 _collateralFactor,
        uint256 _price
    ) external onlyOwner {
        require(!assets[_token].isActive, "Asset already active");

        assets[_token] = Asset({
            tokenAddress: _token,
            totalDeposits: 0,
            totalBorrows: 0,
            baseRate: _baseRate,
            slopeRate: _slopeRate,
            optimalUtilization: _optimalUtilization,
            excessSlope: _excessSlope,
            liquidationThreshold: _liquidationThreshold,
            liquidationBonus: _liquidationBonus,
            collateralFactor: _collateralFactor,
            lastUpdateTimestamp: block.timestamp,
            borrowIndex: INDEX_PRECISION,
            price: _price,
            isActive: true
        });

        assetList.push(_token);
        emit AssetAdded(_token);
    }

    function setPrice(address _token, uint256 _price) external onlyOwner {
        require(assets[_token].isActive, "Asset not active");
        assets[_token].price = _price;
        emit PriceUpdated(_token, _price);
    }

    function getUtilizationRate(address _token) public view returns (uint256) {
        Asset storage asset = assets[_token];
        if (asset.totalDeposits == 0) return 0;
        return (asset.totalBorrows * BASIS_POINTS) / asset.totalDeposits;
    }

    function getBorrowRate(address _token) public view returns (uint256) {
        Asset storage asset = assets[_token];
        uint256 utilization = getUtilizationRate(_token);

        if (utilization <= asset.optimalUtilization) {
            return asset.baseRate + (utilization * asset.slopeRate) / asset.optimalUtilization;
        } else {
            uint256 baseAtOptimal = asset.baseRate + asset.slopeRate;
            uint256 excessUtilization = utilization - asset.optimalUtilization;
            uint256 excessRange = BASIS_POINTS - asset.optimalUtilization;
            return baseAtOptimal + (excessUtilization * asset.excessSlope) / excessRange;
        }
    }

    function getSupplyRate(address _token) public view returns (uint256) {
        uint256 utilization = getUtilizationRate(_token);
        uint256 borrowRate = getBorrowRate(_token);
        return (utilization * borrowRate) / BASIS_POINTS;
    }

    function accrueInterest(address _token) public {
        Asset storage asset = assets[_token];
        if (block.timestamp == asset.lastUpdateTimestamp) return;

        uint256 timeElapsed = block.timestamp - asset.lastUpdateTimestamp;
        uint256 borrowRate = getBorrowRate(_token);

        uint256 interestFactor = (borrowRate * timeElapsed * INDEX_PRECISION) / (BASIS_POINTS * SECONDS_PER_YEAR);
        uint256 interestAccumulated = (asset.totalBorrows * interestFactor) / INDEX_PRECISION;

        asset.totalBorrows += interestAccumulated;
        asset.borrowIndex += (asset.borrowIndex * interestFactor) / INDEX_PRECISION;
        asset.lastUpdateTimestamp = block.timestamp;
    }

    function _getUserBorrowBalance(address _user, address _token) internal view returns (uint256) {
        UserPosition storage pos = userPositions[_user][_token];
        if (pos.borrowAmount == 0) return 0;
        return (pos.borrowAmount * assets[_token].borrowIndex) / pos.borrowIndex;
    }

    function getUserBorrowBalance(address _user, address _token) external view returns (uint256) {
        return _getUserBorrowBalance(_user, _token);
    }

    function deposit(address _token, uint256 _amount) external nonReentrant {
        require(assets[_token].isActive, "Asset not active");
        require(_amount > 0, "Amount must be > 0");

        accrueInterest(_token);

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        assets[_token].totalDeposits += _amount;
        userPositions[msg.sender][_token].depositAmount += _amount;

        emit Deposited(msg.sender, _token, _amount);
    }

    function withdraw(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");

        accrueInterest(_token);

        UserPosition storage pos = userPositions[msg.sender][_token];
        require(pos.depositAmount >= _amount, "Insufficient deposit");

        pos.depositAmount -= _amount;
        assets[_token].totalDeposits -= _amount;

        require(_healthFactor(msg.sender) >= INDEX_PRECISION, "Withdrawal would cause undercollateralization");

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _token, _amount);
    }

    function borrow(address _token, uint256 _amount) external nonReentrant {
        require(assets[_token].isActive, "Asset not active");
        require(_amount > 0, "Amount must be > 0");

        accrueInterest(_token);

        Asset storage asset = assets[_token];
        require(asset.totalDeposits - asset.totalBorrows >= _amount, "Insufficient liquidity");

        UserPosition storage pos = userPositions[msg.sender][_token];

        // Update user borrow with accrued interest
        if (pos.borrowAmount > 0) {
            pos.borrowAmount = _getUserBorrowBalance(msg.sender, _token);
        }
        pos.borrowAmount += _amount;
        pos.borrowIndex = asset.borrowIndex;

        asset.totalBorrows += _amount;

        require(_healthFactor(msg.sender) >= INDEX_PRECISION, "Insufficient collateral");

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Borrowed(msg.sender, _token, _amount);
    }

    function repay(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");

        accrueInterest(_token);

        UserPosition storage pos = userPositions[msg.sender][_token];
        uint256 currentBorrow = _getUserBorrowBalance(msg.sender, _token);
        require(currentBorrow > 0, "No debt to repay");

        uint256 repayAmount = _amount > currentBorrow ? currentBorrow : _amount;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), repayAmount);

        assets[_token].totalBorrows -= repayAmount;
        pos.borrowAmount = currentBorrow - repayAmount;
        pos.borrowIndex = assets[_token].borrowIndex;

        emit Repaid(msg.sender, _token, repayAmount);
    }

    function _totalCollateralValue(address _user) internal view returns (uint256) {
        uint256 totalCollateral = 0;
        for (uint256 i = 0; i < assetList.length; i++) {
            address token = assetList[i];
            uint256 depositAmount = userPositions[_user][token].depositAmount;
            if (depositAmount > 0) {
                Asset storage asset = assets[token];
                totalCollateral += (depositAmount * asset.price * asset.collateralFactor) / (INDEX_PRECISION * BASIS_POINTS);
            }
        }
        return totalCollateral;
    }

    function _totalBorrowValue(address _user) internal view returns (uint256) {
        uint256 totalBorrow = 0;
        for (uint256 i = 0; i < assetList.length; i++) {
            address token = assetList[i];
            uint256 borrowBalance = _getUserBorrowBalance(_user, token);
            if (borrowBalance > 0) {
                totalBorrow += (borrowBalance * assets[token].price) / INDEX_PRECISION;
            }
        }
        return totalBorrow;
    }

    function _liquidationThresholdValue(address _user) internal view returns (uint256) {
        uint256 totalThreshold = 0;
        for (uint256 i = 0; i < assetList.length; i++) {
            address token = assetList[i];
            uint256 depositAmount = userPositions[_user][token].depositAmount;
            if (depositAmount > 0) {
                Asset storage asset = assets[token];
                totalThreshold += (depositAmount * asset.price * asset.liquidationThreshold) / (INDEX_PRECISION * BASIS_POINTS);
            }
        }
        return totalThreshold;
    }

    function _healthFactor(address _user) internal view returns (uint256) {
        uint256 totalBorrow = _totalBorrowValue(_user);
        if (totalBorrow == 0) return type(uint256).max;

        uint256 thresholdValue = _liquidationThresholdValue(_user);
        return (thresholdValue * INDEX_PRECISION) / totalBorrow;
    }

    function healthFactor(address _user) external view returns (uint256) {
        return _healthFactor(_user);
    }

    function getAccountData(address _user) external view returns (
        uint256 totalCollateral,
        uint256 totalBorrow,
        uint256 availableBorrow,
        uint256 currentHealthFactor
    ) {
        totalCollateral = _totalCollateralValue(_user);
        totalBorrow = _totalBorrowValue(_user);
        availableBorrow = totalCollateral > totalBorrow ? totalCollateral - totalBorrow : 0;
        currentHealthFactor = _healthFactor(_user);
    }

    function liquidate(
        address _borrower,
        address _debtToken,
        address _collateralToken,
        uint256 _debtToCover
    ) external nonReentrant {
        require(_borrower != msg.sender, "Cannot liquidate self");

        accrueInterest(_debtToken);
        accrueInterest(_collateralToken);

        require(_healthFactor(_borrower) < INDEX_PRECISION, "Health factor is safe");

        uint256 currentBorrow = _getUserBorrowBalance(_borrower, _debtToken);
        uint256 maxLiquidatable = currentBorrow / 2; // Can liquidate up to 50%
        uint256 actualDebtToCover = _debtToCover > maxLiquidatable ? maxLiquidatable : _debtToCover;

        Asset storage debtAsset = assets[_debtToken];
        Asset storage collateralAsset = assets[_collateralToken];

        // Calculate collateral to seize
        uint256 debtValueUSD = (actualDebtToCover * debtAsset.price) / INDEX_PRECISION;
        uint256 bonusMultiplier = BASIS_POINTS + collateralAsset.liquidationBonus;
        uint256 collateralToSeize = (debtValueUSD * bonusMultiplier * INDEX_PRECISION) / (collateralAsset.price * BASIS_POINTS);

        UserPosition storage borrowerCollateral = userPositions[_borrower][_collateralToken];
        require(borrowerCollateral.depositAmount >= collateralToSeize, "Not enough collateral to seize");

        // Transfer debt tokens from liquidator
        IERC20(_debtToken).safeTransferFrom(msg.sender, address(this), actualDebtToCover);

        // Update borrower's debt
        UserPosition storage borrowerDebt = userPositions[_borrower][_debtToken];
        borrowerDebt.borrowAmount = currentBorrow - actualDebtToCover;
        borrowerDebt.borrowIndex = debtAsset.borrowIndex;
        debtAsset.totalBorrows -= actualDebtToCover;

        // Seize collateral
        borrowerCollateral.depositAmount -= collateralToSeize;
        collateralAsset.totalDeposits -= collateralToSeize;

        IERC20(_collateralToken).safeTransfer(msg.sender, collateralToSeize);

        emit Liquidated(msg.sender, _borrower, _debtToken, _collateralToken, actualDebtToCover, collateralToSeize);
    }

    function getAssetCount() external view returns (uint256) {
        return assetList.length;
    }
}