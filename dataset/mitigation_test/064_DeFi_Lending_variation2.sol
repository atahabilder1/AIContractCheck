```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
    function getPriceDecimals() external view returns (uint8);
}

contract IsolatedLendingPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct Market {
        bool isActive;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 borrowIndex;
        uint256 supplyIndex;
        uint256 lastUpdateTimestamp;
        uint256 reserveFactor; // Basis points (e.g., 1000 = 10%)
        uint256 reserves;
    }

    struct MarketConfig {
        uint256 baseBorrowRate; // Annual rate in basis points
        uint256 multiplier; // Slope of interest rate curve
        uint256 jumpMultiplier; // Jump rate multiplier
        uint256 kink; // Utilization rate where jump occurs (basis points)
        uint256 collateralFactor; // Basis points (e.g., 8000 = 80%)
        uint256 liquidationThreshold; // Basis points (e.g., 8500 = 85%)
        uint256 liquidationPenalty; // Basis points (e.g., 500 = 5%)
        uint256 supplyCap;
        uint256 borrowCap;
    }

    struct UserPosition {
        uint256 supplyBalance;
        uint256 borrowBalance;
        uint256 supplyIndex;
        uint256 borrowIndex;
    }

    struct IsolatedPosition {
        address collateralToken;
        address borrowToken;
        uint256 collateralAmount;
        uint256 borrowAmount;
        uint256 borrowIndex;
        bool isActive;
    }

    // Market data
    mapping(address => Market) public markets;
    mapping(address => MarketConfig) public marketConfigs;
    mapping(address => mapping(address => UserPosition)) public userPositions;
    
    // Isolated positions: user => positionId => position
    mapping(address => mapping(uint256 => IsolatedPosition)) public isolatedPositions;
    mapping(address => uint256) public userPositionCount;

    IPriceOracle public priceOracle;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public closeFactorMantissa = 5000; // 50%

    event MarketAdded(address indexed token);
    event Supply(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Borrow(address indexed user, uint256 indexed positionId, address collateral, address borrow, uint256 amount);
    event Repay(address indexed user, uint256 indexed positionId, uint256 amount);
    event Liquidation(address indexed liquidator, address indexed borrower, uint256 indexed positionId, uint256 repayAmount, uint256 seizeAmount);

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    modifier marketExists(address token) {
        require(markets[token].isActive, "Market does not exist");
        _;
    }

    modifier validPositionId(address user, uint256 positionId) {
        require(positionId < userPositionCount[user], "Invalid position ID");
        require(isolatedPositions[user][positionId].isActive, "Position not active");
        _;
    }

    constructor(address _priceOracle) validAddress(_priceOracle) {
        priceOracle = IPriceOracle(_priceOracle);
    }

    function addMarket(
        address token,
        uint256 baseBorrowRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 kink,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 supplyCap,
        uint256 borrowCap,
        uint256 reserveFactor
    ) external onlyOwner validAddress(token) {
        require(!markets[token].isActive, "Market already exists");
        require(collateralFactor <= BASIS_POINTS, "Invalid collateral factor");
        require(liquidationThreshold <= BASIS_POINTS, "Invalid liquidation threshold");
        require(liquidationPenalty <= BASIS_POINTS, "Invalid liquidation penalty");
        require(collateralFactor < liquidationThreshold, "Collateral factor must be less than liquidation threshold");
        require(reserveFactor <= BASIS_POINTS, "Invalid reserve factor");

        markets[token] = Market({
            isActive: true,
            totalSupply: 0,
            totalBorrow: 0,
            borrowIndex: 1e18,
            supplyIndex: 1e18,
            lastUpdateTimestamp: block.timestamp,
            reserveFactor: reserveFactor,
            reserves: 0
        });

        marketConfigs[token] = MarketConfig({
            baseBorrowRate: baseBorrowRate,
            multiplier: multiplier,
            jumpMultiplier: jumpMultiplier,
            kink: kink,
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            supplyCap: supplyCap,
            borrowCap: borrowCap
        });

        emit MarketAdded(token);
    }

    function supply(address token, uint256 amount) external nonReentrant marketExists(token) {
        require(amount > 0, "Amount must be greater than 0");
        
        Market storage market = markets[token];
        MarketConfig storage config = marketConfigs[token];
        
        require(market.totalSupply + amount <= config.supplyCap, "Supply cap exceeded");

        _accrueInterest(token);

        UserPosition storage position = userPositions[msg.sender][token];
        
        // Update user's supply balance
        if (position.supplyBalance > 0) {
            uint256 supplierAccrued = position.supplyBalance * market.supplyIndex / position.supplyIndex;
            position.supplyBalance = supplierAccrued;
        }
        
        position.supplyBalance += amount;
        position.supplyIndex = market.supplyIndex;
        market.totalSupply += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Supply(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant marketExists(token) {
        require(amount > 0, "Amount must be greater than 0");

        _accrueInterest(token);

        Market storage market = markets[token];
        UserPosition storage position = userPositions[msg.sender][token];

        // Calculate current balance
        uint256 currentBalance = position.supplyBalance * market.supplyIndex / position.supplyIndex;
        require(currentBalance >= amount, "Insufficient balance");

        // Update position
        position.supplyBalance = currentBalance - amount;
        position.supplyIndex = market.supplyIndex;
        market.totalSupply -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    function borrowIsolated(
        address collateralToken,
        address borrowToken,
        uint256 borrowAmount
    ) external nonReentrant marketExists(collateralToken) marketExists(borrowToken) {
        require(borrowAmount > 0, "Amount must be greater than 0");
        require(collateralToken != borrowToken, "Cannot use same token as collateral and borrow");

        _accrueInterest(collateralToken);
        _accrueInterest(borrowToken);

        Market storage borrowMarket = markets[borrowToken];
        MarketConfig storage borrowConfig = marketConfigs[borrowToken];
        
        require(borrowMarket.totalBorrow + borrowAmount <= borrowConfig.borrowCap, "Borrow cap exceeded");

        // Check user has collateral
        UserPosition storage collateralPosition = userPositions[msg.sender][collateralToken];
        uint256 collateralBalance = collateralPosition.supplyBalance * markets[collateralToken].supplyIndex / collateralPosition.supplyIndex;
        require(collateralBalance > 0, "No collateral supplied");

        // Calculate required collateral
        uint256 borrowValue = _getTokenValue(borrowToken, borrowAmount);
        uint256 requiredCollateralValue = borrowValue * BASIS_POINTS / marketConfigs[collateralToken].collateralFactor;
        uint256 collateralValue = _getTokenValue(collateralToken, collateralBalance);
        
        require(collateralValue >= requiredCollateralValue, "Insufficient collateral");

        // Create isolated position
        uint256 positionId = userPositionCount[msg.sender];
        isolatedPositions[msg.sender][positionId] = IsolatedPosition({
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralBalance,
            borrowAmount: borrowAmount,
            borrowIndex: borrowMarket.borrowIndex,
            isActive: true
        });

        userPositionCount[msg.sender]++;
        borrowMarket.totalBorrow += borrowAmount;

        // Lock collateral
        collateralPosition.supplyBalance = 0;

        IERC20(borrowToken).safeTransfer(msg.sender, borrowAmount);

        emit Borrow(msg.sender, positionId, collateralToken, borrowToken, borrowAmount);
    }

    function repayIsolated(uint256 positionId, uint256 repayAmount) external nonReentrant validPositionId(msg.sender, positionId) {
        require(repayAmount > 0, "Amount must be greater than 0");

        IsolatedPosition storage position = isolatedPositions[msg.sender][positionId];
        
        _accrueInterest(position.borrowToken);

        Market storage borrowMarket = markets[position.borrowToken];
        
        // Calculate current debt
        uint256 currentDebt = position.borrowAmount * borrowMarket.borrowIndex / position.borrowIndex;
        require(repayAmount <= currentDebt, "Repay amount exceeds debt");

        // Update position
        if (repayAmount == currentDebt) {
            // Full repayment - unlock collateral
            UserPosition storage collateralPosition = userPositions[msg.sender][position.collateralToken];
            collateralPosition.supplyBalance = position.collateralAmount;
            collateralPosition.supplyIndex = markets[position.collateralToken].supplyIndex;
            
            position.isActive = false;
        } else {
            // Partial repayment
            position.borrowAmount = currentDebt - repayAmount;
            position.borrowIndex = borrowMarket.borrowIndex;
        }

        borrowMarket.totalBorrow -= repayAmount;

        IERC20(position.borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, positionId, repayAmount);
    }

    function liquidateIsolated(
        address borrower,
        uint256 positionId,
        uint256 repayAmount
    ) external nonReentrant validPositionId(borrower, positionId) {
        IsolatedPosition storage position = isolatedPositions[borrower][positionId];
        
        _accrueInterest(position.collateralToken);
        _accrueInterest(position.borrowToken);

        // Check if position is liquidatable
        require(_isLiquidatable(borrower, positionId), "Position not liquidatable");

        Market storage borrowMarket = markets[position.borrowToken];
        MarketConfig storage borrowConfig = marketConfigs[position.borrowToken];
        
        // Calculate current debt
        uint256 currentDebt = position.borrowAmount * borrowMarket.borrowIndex / position.borrowIndex;
        
        // Validate repay amount
        uint256 maxRepay = currentDebt * closeFactorMantissa / BASIS_POINTS;
        require(repayAmount <= maxRepay, "Repay amount too high");

        // Calculate seize amount
        uint256 repayValue = _getTokenValue(position.borrowToken, repayAmount);
        uint256 incentiveValue = repayValue * (BASIS_POINTS + borrowConfig.liquidationPenalty) / BASIS_POINTS;
        uint256 seizeAmount = incentiveValue * (10 ** IERC20(position.collateralToken).decimals()) / _getTokenValue(position.collateralToken, 10 ** IERC20(position.collateralToken).decimals());
        
        require(seizeAmount <= position.collateralAmount, "Seize amount exceeds collateral");

        // Update position
        position.borrowAmount = currentDebt - repayAmount;
        position.borrowIndex = borrowMarket.borrowIndex;
        position.collateralAmount -= seizeAmount;

        if (position.borrowAmount == 0 || position.collateralAmount == 0) {
            // Return remaining collateral to borrower
            if (position.collateralAmount > 0) {
                UserPosition storage collateralPosition = userPositions[borrower][position.collateralToken];
                collateralPosition.supplyBalance += position.collateralAmount;
                collateralPosition.supplyIndex = markets[position.collateralToken].supplyIndex;
            }
            position.isActive = false;
        }

        borrowMarket.totalBorrow -= repayAmount;

        // Transfer tokens
        IERC20(position.borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);
        IERC20(position.collateralToken).safeTransfer(msg.sender, seizeAmount);

        emit Liquidation(msg.sender, borrower, positionId, repayAmount, seizeAmount);
    }

    function _accrueInterest(address token) internal {
        Market storage market = markets[token];
        MarketConfig storage config = marketConfigs[token];

        if (block.timestamp == market.lastUpdateTimestamp) {
            return;
        }

        uint256 timeDelta = block.timestamp - market.lastUpdateTimestamp;
        uint256 borrowRate = _getBorrowRate(token);
        uint256 interestAccumulated = market.totalBorrow * borrowRate * timeDelta / (SECONDS_PER_YEAR * 1e18);

        market.totalBorrow += interestAccumulated;
        market.borrowIndex += market.borrowIndex * borrowRate * timeDelta / (SECONDS_PER_YEAR * 1e18);

        uint256 reserveAmount = interestAccumulated * market.reserveFactor / BASIS_POINTS;
        market.reserves += reserveAmount;

        uint256 supplyInterest = interestAccumulated - reserveAmount;
        if (market.totalSupply > 0) {
            market.supplyIndex += market.supplyIndex * supplyInterest / market.totalSupply;
        }

        market.lastUpdateTimestamp = block.timestamp;
    }

    function _getBorrowRate(address token) internal