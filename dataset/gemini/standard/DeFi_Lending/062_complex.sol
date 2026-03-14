```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingProtocol is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // --- Structs ---

    struct AssetConfig {
        IERC20 token;
        uint256 interestRateModelIndex; // Index into the `interestRateModels` array
        uint256 collateralFactor; // e.g., 8000 for 80%
        uint256 liquidationThreshold; // e.g., 8500 for 85%
        uint256 liquidationBonus; // e.g., 1050 for 5% bonus
        uint256 reserveFactor; // e.g., 1000 for 10% to reserves
        bool isListed;
    }

    struct UserAssetInfo {
        uint256 principal; // Amount borrowed
        uint256 interestIndex; // User's current index of accrued interest
        uint256 collateral; // Amount deposited as collateral
    }

    struct InterestRateModel {
        uint256 baseRate; // Base interest rate
        uint256 multiplier; // Multiplier for utilization
        uint256 optimalUtilization; // Utilization percentage at which the rate is optimal
    }

    // --- State Variables ---

    address[] public assetTokens; // Addresses of listed tokens
    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => uint256) public assetBalances; // Total supplied balance of each asset
    mapping(address => uint256) public assetBorrows; // Total borrowed balance of each asset
    mapping(address => uint256) public interestIndex; // Global interest index for each asset

    InterestRateModel[] public interestRateModels;

    mapping(address => mapping(address => UserAssetInfo)) public userAssetInfo; // user => asset => info

    uint256 public constant INTEREST_INDEX_SCALING_FACTOR = 1e18;
    uint256 public constant PERCENTAGE_SCALING_FACTOR = 1e4;
    uint256 public constant LIQUIDATION_BONUS_SCALING_FACTOR = 1e3;
    uint256 public constant RESERVE_FACTOR_SCALING_FACTOR = 1e4;

    // --- Events ---

    event AssetListed(address indexed token);
    event AssetDelisted(address indexed token);
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Liquidation(
        address indexed liquidator,
        address indexed user,
        address indexed assetToLiquidate,
        uint256 repayAmount,
        address indexed collateralToSeize,
        uint256 seizeAmount
    );
    event FlashLoan(address indexed borrower, address indexed asset, uint256 amount, uint256 fee);

    // --- Modifiers ---

    modifier assetIsListed(address _asset) {
        require(assetConfigs[_asset].isListed, "Asset not listed");
        _;
    }

    modifier assetIsNotListed(address _asset) {
        require(!assetConfigs[_asset].isListed, "Asset already listed");
        _;
    }

    modifier onlyAssetOwner(address _asset) {
        require(msg.sender == owner(), "Only owner can manage this asset");
        _;
    }

    // --- Constructor ---

    constructor() Ownable(msg.sender) {
        // Add a default interest rate model
        interestRateModels.push(InterestRateModel({
            baseRate: 200, // 2%
            multiplier: 2000, // 20% multiplier
            optimalUtilization: 8000 // 80%
        }));
    }

    // --- Owner Functions ---

    function addInterestRateModel(uint256 _baseRate, uint256 _multiplier, uint256 _optimalUtilization) external onlyOwner {
        interestRateModels.push(InterestRateModel({
            baseRate: _baseRate,
            multiplier: _multiplier,
            optimalUtilization: _optimalUtilization
        }));
    }

    function updateInterestRateModel(uint256 _index, uint256 _baseRate, uint256 _multiplier, uint256 _optimalUtilization) external onlyOwner {
        require(_index < interestRateModels.length, "Invalid index");
        interestRateModels[_index] = InterestRateModel({
            baseRate: _baseRate,
            multiplier: _multiplier,
            optimalUtilization: _optimalUtilization
        });
    }

    function listAsset(
        address _token,
        uint256 _interestRateModelIndex,
        uint256 _collateralFactor,
        uint256 _liquidationThreshold,
        uint256 _liquidationBonus,
        uint256 _reserveFactor
    ) external onlyOwner assetIsNotListed(_token) {
        require(_collateralFactor < PERCENTAGE_SCALING_FACTOR, "Collateral factor too high");
        require(_liquidationThreshold < PERCENTAGE_SCALING_FACTOR, "Liquidation threshold too high");
        require(_collateralFactor <= _liquidationThreshold, "Collateral factor must be <= liquidation threshold");
        require(_liquidationBonus < PERCENTAGE_SCALING_FACTOR, "Liquidation bonus too high");
        require(_reserveFactor < PERCENTAGE_SCALING_FACTOR, "Reserve factor too high");
        require(_interestRateModelIndex < interestRateModels.length, "Invalid interest rate model index");

        assetTokens.push(_token);
        assetConfigs[_token] = AssetConfig({
            token: IERC20(_token),
            interestRateModelIndex: _interestRateModelIndex,
            collateralFactor: _collateralFactor,
            liquidationThreshold: _liquidationThreshold,
            liquidationBonus: _liquidationBonus,
            reserveFactor: _reserveFactor,
            isListed: true
        });

        // Initialize global state for the new asset
        interestIndex[_token] = INTEREST_INDEX_SCALING_FACTOR;
        assetBalances[_token] = 0;
        assetBorrows[_token] = 0;

        emit AssetListed(_token);
    }

    function delistAsset(address _token) external onlyOwner assetIsListed(_token) {
        AssetConfig storage config = assetConfigs[_token];
        require(assetBorrows[_token] == 0, "Cannot delist asset with outstanding borrows");
        require(assetBalances[_token] == 0, "Cannot delist asset with outstanding supplies");

        config.isListed = false;
        // Remove from assetTokens array (optional, can be done by filtering later)
        for (uint256 i = 0; i < assetTokens.length; i++) {
            if (assetTokens[i] == _token) {
                assetTokens[i] = assetTokens[assetTokens.length - 1];
                assetTokens.pop();
                break;
            }
        }

        emit AssetDelisted(_token);
    }

    function updateAssetConfig(
        address _token,
        uint256 _interestRateModelIndex,
        uint256 _collateralFactor,
        uint256 _liquidationThreshold,
        uint256 _liquidationBonus,
        uint256 _reserveFactor
    ) external onlyOwner assetIsListed(_token) {
        require(_collateralFactor < PERCENTAGE_SCALING_FACTOR, "Collateral factor too high");
        require(_liquidationThreshold < PERCENTAGE_SCALING_FACTOR, "Liquidation threshold too high");
        require(_collateralFactor <= _liquidationThreshold, "Collateral factor must be <= liquidation threshold");
        require(_liquidationBonus < PERCENTAGE_SCALING_FACTOR, "Liquidation bonus too high");
        require(_reserveFactor < PERCENTAGE_SCALING_FACTOR, "Reserve factor too high");
        require(_interestRateModelIndex < interestRateModels.length, "Invalid interest rate model index");

        AssetConfig storage config = assetConfigs[_token];
        config.interestRateModelIndex = _interestRateModelIndex;
        config.collateralFactor = _collateralFactor;
        config.liquidationThreshold = _liquidationThreshold;
        config.liquidationBonus = _liquidationBonus;
        config.reserveFactor = _reserveFactor;
    }

    // --- Core Functions ---

    function deposit(address _asset, uint256 _amount) external nonReentrant assetIsListed(_asset) {
        require(_amount > 0, "Amount must be positive");

        AssetConfig storage config = assetConfigs[_asset];
        IERC20 token = config.token;

        token.safeTransferFrom(msg.sender, address(this), _amount);

        _updateInterest(_asset); // Accrue interest before updating user info

        UserAssetInfo storage userInfo = userAssetInfo[msg.sender][_asset];
        userInfo.collateral = userInfo.collateral.add(_amount);
        assetBalances[_asset] = assetBalances[_asset].add(_amount);

        emit Deposit(msg.sender, _asset, _amount);
    }

    function withdraw(address _asset, uint256 _amount) external nonReentrant assetIsListed(_asset) {
        require(_amount > 0, "Amount must be positive");

        AssetConfig storage config = assetConfigs[_asset];
        IERC20 token = config.token;

        _updateInterest(_asset); // Accrue interest before checking user info

        UserAssetInfo storage userInfo = userAssetInfo[msg.sender][_asset];
        uint256 userCollateral = userInfo.collateral;
        uint256 userPrincipal = userInfo.principal;

        // Calculate current borrowable amount after interest
        uint256 borrowableAmount = _getBorrowableAmount(msg.sender);

        // Check if withdrawal would violate collateralization
        // Current collateral value - withdrawal amount * collateral factor must be >= current principal
        uint256 currentCollateralValue = _getAssetValue(_asset, userCollateral);
        uint256 currentPrincipalValue = _getAssetValue(_asset, userPrincipal); // Approximation, actual value might differ

        // More robust check: Ensure the user can still borrow their current principal after withdrawal
        // If user withdraws X, their collateral becomes userCollateral - X.
        // The total value of collateral should be at least (userPrincipal * 10000) / collateralFactor.
        // (userCollateral - X) * price >= userPrincipal * price * 10000 / collateralFactor
        // userCollateral - X >= userPrincipal * 10000 / collateralFactor
        // userCollateral - (userPrincipal * 10000 / collateralFactor) >= X

        uint256 maxWithdrawalBasedOnCollateral = 0;
        if (config.collateralFactor > 0) {
            uint256 requiredCollateralForBorrow = currentPrincipalValue.mul(PERCENTAGE_SCALING_FACTOR).div(config.collateralFactor);
            if (currentCollateralValue > requiredCollateralForBorrow) {
                maxWithdrawalBasedOnCollateral = currentCollateralValue.sub(requiredCollateralForBorrow).div(config.collateralFactor); // This is an approximation, needs price oracle
            }
        }

        // The actual withdrawal amount cannot exceed the user's deposited collateral minus the required collateral for their current borrows.
        // This calculation is simplified and assumes the same asset for collateral and borrow for simplicity in this example.
        // A real protocol would use a price oracle to convert all collateral to a common currency (e.g., USD) and compare against borrows.

        uint256 maxUserWithdrawal = userCollateral;
        // Need to consider the user's borrow limit
        // For simplicity, let's assume the user can withdraw up to their collateral amount,
        // as long as their health factor remains above 1.
        // A proper implementation would check the health factor:
        // (TotalCollateralValue / TotalBorrowValue) > 1

        // Simplified check: Ensure user has enough collateral to cover the withdrawal
        require(userCollateral >= _amount, "Insufficient collateral");

        token.safeTransfer(msg.sender, _amount);

        userInfo.collateral = userInfo.collateral.sub(_amount);
        assetBalances[_asset] = assetBalances[_asset].sub(_amount);

        emit Withdraw(msg.sender, _asset, _amount);
    }

    function borrow(address _asset, uint256 _amount) external nonReentrant assetIsListed(_asset) {
        require(_amount > 0, "Amount must be positive");

        AssetConfig storage config = assetConfigs[_asset];
        IERC20 token = config.token;

        _updateInterest(_asset); // Accrue interest before checking user info

        UserAssetInfo storage userInfo = userAssetInfo[msg.sender][_asset];
        uint256 userPrincipal = userInfo.principal;
        uint256 userCollateral = userInfo.collateral;

        // Check if user has enough borrowable amount
        uint256 borrowableAmount = _getBorrowableAmount(msg.sender);
        require(borrowableAmount >= _amount, "Insufficient borrowable amount");

        // Check if borrowing this amount would make the asset's utilization too high
        uint256 requestedBorrow = _amount;
        uint256 totalBorrowsAfter = assetBorrows[_asset].add(requestedBorrow);
        uint256 totalSupplies = assetBalances[_asset];
        uint256 utilization = 0;
        if (totalSupplies > 0) {
            utilization = totalBorrowsAfter.mul(PERCENTAGE_SCALING_FACTOR).div(totalSupplies);
        }
        // We might want to cap utilization to avoid infinite interest rates
        // For simplicity, we assume the interest rate model handles this.

        token.safeTransfer(msg.sender, _amount);

        userInfo.principal = userInfo.principal.add(_amount);
        assetBorrows[_asset] = assetBorrows[_asset].add(_amount);

        emit Borrow(msg.sender, _asset, _amount);
    }

    function repay(address _asset, uint256 _amount) external nonReentrant assetIsListed(_asset) {
        require(_amount > 0, "Amount must be positive");

        AssetConfig storage config = assetConfigs[_asset];
        IERC20 token = config.token;

        _updateInterest(_asset); // Accrue interest before updating user info

        UserAssetInfo storage userInfo = userAssetInfo[msg.sender][_asset];
        uint256 userPrincipal = userInfo.principal;

        require(userPrincipal > 0, "No outstanding borrow for this asset");

        uint256 amountToRepay = _amount;
        uint256 actualRepayAmount = amountToRepay;

        if (amountToRepay > userPrincipal) {
            actualRepayAmount = userPrincipal;
        }

        token.safeTransferFrom(msg.sender, address(this), actualRepayAmount);

        userInfo.principal = userInfo.principal.sub(actualRepayAmount);
        assetBorrows[_asset] = assetBorrows[_asset].sub(actualRepayAmount);

        emit Repay(msg.sender, _asset, actualRepayAmount);

        // If user repaid more than their principal, the excess is a deposit
        if (_amount > actualRepayAmount) {
            uint256 excessAmount = _amount.sub(actualRepayAmount);
            userInfo.collateral = userInfo.collateral.add(excessAmount);
            assetBalances[_asset] = assetBalances[_asset].add(excessAmount);
            emit Deposit(msg.sender, _asset, excessAmount);
        }
    }

    function liquidate(address _user, address _assetToLiquidate) external nonReentrant {
        require(assetConfigs[_assetToLiquidate].isListed, "Asset to liquidate not listed");
        require(_user != address(0), "Invalid user");

        _updateInterest(_assetToLiquidate); // Ensure interest is up-to-date for the asset being liquidated

        uint256 borrowBalance = userAssetInfo[_user][_assetToLiquidate].principal;
        require(borrowBalance > 0, "User has no borrow for this asset");

        // Check if the user is underwater (health factor < 1)
        if (!_isLiquidatable(_user)) {
            revert("User is not liquidatable");
        }

        AssetConfig storage assetConfig = assetConfigs[_assetToLiquidate];
        uint256 liquidationBonus = assetConfig.liquidationBonus;
        uint256 liquidationThreshold = assetConfig.liquidationThreshold;

        // Determine the amount to repay (can be up to the liquidation threshold)
        // For simplicity, we'll allow liquidator to repay up to the full borrow balance.
        // A more complex system might calculate an optimal liquidation amount.