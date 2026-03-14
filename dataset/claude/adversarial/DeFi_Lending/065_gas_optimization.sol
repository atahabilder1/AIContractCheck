// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DeFiLending {
    using SafeERC20 for IERC20;

    struct Market {
        uint128 totalDeposits;
        uint128 totalBorrows;
        uint128 reserveFactor;
        uint128 lastAccrualBlock;
        uint256 borrowIndex;
    }

    struct UserAccount {
        uint128 deposited;
        uint128 borrowed;
        uint256 borrowIndexAtEntry;
    }

    address public immutable owner;
    uint256 public constant COLLATERAL_FACTOR = 7500; // 75% LTV
    uint256 public constant LIQUIDATION_THRESHOLD = 8500; // 85%
    uint256 public constant LIQUIDATION_BONUS = 500; // 5%
    uint256 public constant BASE_RATE = 2e16; // 2% base
    uint256 public constant SLOPE = 20e16; // 20% slope
    uint256 public constant BPS = 10000;
    uint256 public constant BLOCKS_PER_YEAR = 2_628_000;
    uint256 public constant INDEX_PRECISION = 1e18;

    mapping(address token => Market) public markets;
    mapping(address token => mapping(address user => UserAccount)) public accounts;
    mapping(address token => mapping(address user => uint256)) public collateral;
    mapping(address token => uint256) public prices; // price in 1e18

    event Deposit(address indexed token, address indexed user, uint256 amount);
    event Withdraw(address indexed token, address indexed user, uint256 amount);
    event Borrow(address indexed token, address indexed user, uint256 amount);
    event Repay(address indexed token, address indexed user, uint256 amount);
    event Liquidate(address indexed borrower, address indexed liquidator, address debtToken, address collateralToken, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function initMarket(address token, uint128 reserveFactor) external onlyOwner {
        Market storage m = markets[token];
        m.reserveFactor = reserveFactor;
        m.lastAccrualBlock = uint128(block.number);
        m.borrowIndex = INDEX_PRECISION;
    }

    function setPrice(address token, uint256 price) external onlyOwner {
        prices[token] = price;
    }

    function _accrueInterest(Market storage m) internal {
        uint256 blockDelta = block.number - m.lastAccrualBlock;
        if (blockDelta == 0) return;

        m.lastAccrualBlock = uint128(block.number);
        uint128 totalBorrows = m.totalBorrows;
        if (totalBorrows == 0) return;

        uint256 utilization = (uint256(totalBorrows) * INDEX_PRECISION) / (uint256(m.totalDeposits) + totalBorrows);
        uint256 borrowRate = BASE_RATE + (utilization * SLOPE) / INDEX_PRECISION;
        uint256 interestPerBlock = borrowRate / BLOCKS_PER_YEAR;
        uint256 interestAccumulated = interestPerBlock * blockDelta;

        m.borrowIndex += (m.borrowIndex * interestAccumulated) / INDEX_PRECISION;
        uint256 newInterest = (uint256(totalBorrows) * interestAccumulated) / INDEX_PRECISION;
        m.totalBorrows = totalBorrows + uint128(newInterest);
    }

    function _currentBorrow(UserAccount storage acc, uint256 currentIndex) internal view returns (uint256) {
        if (acc.borrowed == 0) return 0;
        return (uint256(acc.borrowed) * currentIndex) / acc.borrowIndexAtEntry;
    }

    function deposit(address token, uint128 amount) external {
        Market storage m = markets[token];
        _accrueInterest(m);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        m.totalDeposits += amount;
        accounts[token][msg.sender].deposited += amount;
        collateral[token][msg.sender] += amount;

        emit Deposit(token, msg.sender, amount);
    }

    function withdraw(address token, uint128 amount) external {
        Market storage m = markets[token];
        _accrueInterest(m);

        UserAccount storage acc = accounts[token][msg.sender];
        acc.deposited -= amount;
        collateral[token][msg.sender] -= amount;
        m.totalDeposits -= amount;

        require(_isHealthy(msg.sender), "undercollateralized");

        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw(token, msg.sender, amount);
    }

    function borrow(address token, uint128 amount) external {
        Market storage m = markets[token];
        _accrueInterest(m);

        UserAccount storage acc = accounts[token][msg.sender];
        uint256 existingDebt = _currentBorrow(acc, m.borrowIndex);

        acc.borrowed = uint128(existingDebt + amount);
        acc.borrowIndexAtEntry = m.borrowIndex;
        m.totalBorrows += amount;

        require(_isHealthy(msg.sender), "undercollateralized");

        IERC20(token).safeTransfer(msg.sender, amount);
        emit Borrow(token, msg.sender, amount);
    }

    function repay(address token, uint128 amount) external {
        Market storage m = markets[token];
        _accrueInterest(m);

        UserAccount storage acc = accounts[token][msg.sender];
        uint256 owed = _currentBorrow(acc, m.borrowIndex);
        uint256 repayAmount = amount > owed ? uint128(owed) : amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), repayAmount);

        acc.borrowed = uint128(owed - repayAmount);
        acc.borrowIndexAtEntry = m.borrowIndex;
        m.totalBorrows -= uint128(repayAmount);

        emit Repay(token, msg.sender, repayAmount);
    }

    function liquidate(address borrower, address debtToken, address collateralToken, uint128 amount) external {
        Market storage debtMarket = markets[debtToken];
        Market storage collMarket = markets[collateralToken];
        _accrueInterest(debtMarket);
        _accrueInterest(collMarket);

        require(!_isHealthyForLiquidation(borrower), "healthy");

        UserAccount storage debtAcc = accounts[debtToken][borrower];
        uint256 owed = _currentBorrow(debtAcc, debtMarket.borrowIndex);
        uint256 maxRepay = owed / 2;
        uint256 repayAmount = amount > maxRepay ? maxRepay : amount;

        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), repayAmount);
        debtAcc.borrowed = uint128(owed - repayAmount);
        debtAcc.borrowIndexAtEntry = debtMarket.borrowIndex;
        debtMarket.totalBorrows -= uint128(repayAmount);

        uint256 collValue = (repayAmount * prices[debtToken] * (BPS + LIQUIDATION_BONUS)) / (prices[collateralToken] * BPS);
        uint128 collSeized = uint128(collValue);

        collateral[collateralToken][borrower] -= collSeized;
        accounts[collateralToken][borrower].deposited -= collSeized;
        collMarket.totalDeposits -= collSeized;

        IERC20(collateralToken).safeTransfer(msg.sender, collSeized);
        emit Liquidate(borrower, msg.sender, debtToken, collateralToken, repayAmount);
    }

    function _isHealthy(address user) internal view returns (bool) {
        return _totalCollateralValue(user) * COLLATERAL_FACTOR / BPS >= _totalBorrowValue(user);
    }

    function _isHealthyForLiquidation(address user) internal view returns (bool) {
        return _totalCollateralValue(user) * LIQUIDATION_THRESHOLD / BPS >= _totalBorrowValue(user);
    }

    function _totalCollateralValue(address user) internal view returns (uint256) {
        // In production, iterate registered markets. Simplified for gas optimization.
        return 0; // Override with actual market enumeration
    }

    function _totalBorrowValue(address user) internal view returns (uint256) {
        return 0; // Override with actual market enumeration
    }

    // --- Multi-token health check via explicit token arrays ---

    function getHealthFactor(address user, address[] calldata tokens) external view returns (uint256) {
        uint256 totalColl;
        uint256 totalDebt;
        uint256 len = tokens.length;
        for (uint256 i; i < len;) {
            address t = tokens[i];
            uint256 p = prices[t];
            totalColl += collateral[t][user] * p;

            Market storage m = markets[t];
            UserAccount storage acc = accounts[t][user];
            if (acc.borrowed > 0) {
                totalDebt += _currentBorrow(acc, m.borrowIndex) * p;
            }
            unchecked { ++i; }
        }
        if (totalDebt == 0) return type(uint256).max;
        return (totalColl * COLLATERAL_FACTOR) / (totalDebt * BPS / INDEX_PRECISION);
    }

    function isHealthy(address user, address[] calldata tokens) public view returns (bool) {
        uint256 totalColl;
        uint256 totalDebt;
        uint256 len = tokens.length;
        for (uint256 i; i < len;) {
            address t = tokens[i];
            uint256 p = prices[t];
            totalColl += collateral[t][user] * p;

            Market storage m = markets[t];
            UserAccount storage acc = accounts[t][user];
            if (acc.borrowed > 0) {
                totalDebt += _currentBorrow(acc, m.borrowIndex) * p;
            }
            unchecked { ++i; }
        }
        return totalColl * COLLATERAL_FACTOR / BPS >= totalDebt;
    }
}