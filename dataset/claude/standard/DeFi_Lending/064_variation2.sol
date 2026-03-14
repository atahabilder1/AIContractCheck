// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract IsolatedLendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct MarketParams {
        address collateralToken;
        address borrowToken;
        uint256 ltvBps;              // Loan-to-value in basis points (e.g., 7500 = 75%)
        uint256 liquidationThresholdBps; // Liquidation threshold in bps
        uint256 liquidationBonusBps;     // Bonus for liquidators in bps (e.g., 500 = 5%)
        uint256 borrowRatePerSecond;     // Interest rate per second (scaled by 1e18)
        bool active;
    }

    struct Market {
        MarketParams params;
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 totalShares;
        uint256 lastAccrualTimestamp;
        uint256 borrowIndex;         // Scaled by 1e18
    }

    struct Position {
        uint256 collateralAmount;
        uint256 borrowShares;
    }

    uint256 private constant BPS = 10_000;
    uint256 private constant PRECISION = 1e18;

    uint256 public nextMarketId;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => uint256)) public depositShares;
    mapping(uint256 => mapping(address => Position)) public positions;

    event MarketCreated(uint256 indexed marketId, address collateralToken, address borrowToken);
    event Deposited(uint256 indexed marketId, address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(uint256 indexed marketId, address indexed user, uint256 amount, uint256 shares);
    event CollateralSupplied(uint256 indexed marketId, address indexed user, uint256 amount);
    event CollateralWithdrawn(uint256 indexed marketId, address indexed user, uint256 amount);
    event Borrowed(uint256 indexed marketId, address indexed user, uint256 amount);
    event Repaid(uint256 indexed marketId, address indexed user, uint256 amount);
    event Liquidated(uint256 indexed marketId, address indexed borrower, address indexed liquidator, uint256 repaid, uint256 collateralSeized);

    constructor() Ownable(msg.sender) {}

    function createMarket(
        address collateralToken,
        address borrowToken,
        uint256 ltvBps,
        uint256 liquidationThresholdBps,
        uint256 liquidationBonusBps,
        uint256 borrowRatePerSecond
    ) external onlyOwner returns (uint256 marketId) {
        require(collateralToken != borrowToken, "Same token");
        require(ltvBps < liquidationThresholdBps, "LTV >= threshold");
        require(liquidationThresholdBps <= BPS, "Threshold > 100%");
        require(liquidationBonusBps <= 2000, "Bonus too high");

        marketId = nextMarketId++;
        Market storage m = markets[marketId];
        m.params = MarketParams({
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            ltvBps: ltvBps,
            liquidationThresholdBps: liquidationThresholdBps,
            liquidationBonusBps: liquidationBonusBps,
            borrowRatePerSecond: borrowRatePerSecond,
            active: true
        });
        m.lastAccrualTimestamp = block.timestamp;
        m.borrowIndex = PRECISION;

        emit MarketCreated(marketId, collateralToken, borrowToken);
    }

    function deposit(uint256 marketId, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        require(m.params.active, "Inactive market");
        _accrueInterest(m);

        uint256 shares;
        if (m.totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * m.totalShares) / m.totalDeposits;
        }
        require(shares > 0, "Zero shares");

        m.totalDeposits += amount;
        m.totalShares += shares;
        depositShares[marketId][msg.sender] += shares;

        IERC20(m.params.borrowToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(marketId, msg.sender, amount, shares);
    }

    function withdraw(uint256 marketId, uint256 shares) external nonReentrant {
        Market storage m = markets[marketId];
        _accrueInterest(m);

        require(depositShares[marketId][msg.sender] >= shares, "Insufficient shares");

        uint256 amount = (shares * m.totalDeposits) / m.totalShares;
        require(amount <= m.totalDeposits - m.totalBorrows, "Insufficient liquidity");

        m.totalDeposits -= amount;
        m.totalShares -= shares;
        depositShares[marketId][msg.sender] -= shares;

        IERC20(m.params.borrowToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(marketId, msg.sender, amount, shares);
    }

    function supplyCollateral(uint256 marketId, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        require(m.params.active, "Inactive market");

        positions[marketId][msg.sender].collateralAmount += amount;
        IERC20(m.params.collateralToken).safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralSupplied(marketId, msg.sender, amount);
    }

    function withdrawCollateral(uint256 marketId, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        _accrueInterest(m);

        Position storage pos = positions[marketId][msg.sender];
        require(pos.collateralAmount >= amount, "Insufficient collateral");

        pos.collateralAmount -= amount;
        require(_isHealthy(m, pos), "Unhealthy after withdrawal");

        IERC20(m.params.collateralToken).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(marketId, msg.sender, amount);
    }

    function borrow(uint256 marketId, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        require(m.params.active, "Inactive market");
        _accrueInterest(m);

        require(amount <= m.totalDeposits - m.totalBorrows, "Insufficient liquidity");

        uint256 borrowSharesAmount = _toBorrowShares(m, amount);
        positions[marketId][msg.sender].borrowShares += borrowSharesAmount;
        m.totalBorrows += amount;

        require(_isHealthy(m, positions[marketId][msg.sender]), "Unhealthy position");

        IERC20(m.params.borrowToken).safeTransfer(msg.sender, amount);
        emit Borrowed(marketId, msg.sender, amount);
    }

    function repay(uint256 marketId, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        _accrueInterest(m);

        Position storage pos = positions[marketId][msg.sender];
        uint256 owed = _borrowShareToAmount(m, pos.borrowShares);
        if (amount > owed) amount = owed;

        uint256 sharesToBurn = _toBorrowShares(m, amount);
        if (sharesToBurn > pos.borrowShares) sharesToBurn = pos.borrowShares;

        pos.borrowShares -= sharesToBurn;
        m.totalBorrows -= amount;

        IERC20(m.params.borrowToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Repaid(marketId, msg.sender, amount);
    }

    function liquidate(uint256 marketId, address borrower, uint256 repayAmount) external nonReentrant {
        Market storage m = markets[marketId];
        _accrueInterest(m);

        Position storage pos = positions[marketId][borrower];
        require(!_isHealthy(m, pos), "Position is healthy");

        uint256 owed = _borrowShareToAmount(m, pos.borrowShares);
        if (repayAmount > owed) repayAmount = owed;

        uint256 collateralToSeize = (repayAmount * (BPS + m.params.liquidationBonusBps)) / BPS;
        if (collateralToSeize > pos.collateralAmount) {
            collateralToSeize = pos.collateralAmount;
        }

        uint256 sharesToBurn = _toBorrowShares(m, repayAmount);
        if (sharesToBurn > pos.borrowShares) sharesToBurn = pos.borrowShares;

        pos.borrowShares -= sharesToBurn;
        pos.collateralAmount -= collateralToSeize;
        m.totalBorrows -= repayAmount;

        IERC20(m.params.borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);
        IERC20(m.params.collateralToken).safeTransfer(msg.sender, collateralToSeize);

        emit Liquidated(marketId, borrower, msg.sender, repayAmount, collateralToSeize);
    }

    function updateMarketParams(
        uint256 marketId,
        uint256 ltvBps,
        uint256 liquidationThresholdBps,
        uint256 liquidationBonusBps,
        uint256 borrowRatePerSecond
    ) external onlyOwner {
        Market storage m = markets[marketId];
        require(ltvBps < liquidationThresholdBps, "LTV >= threshold");
        require(liquidationThresholdBps <= BPS, "Threshold > 100%");

        _accrueInterest(m);
        m.params.ltvBps = ltvBps;
        m.params.liquidationThresholdBps = liquidationThresholdBps;
        m.params.liquidationBonusBps = liquidationBonusBps;
        m.params.borrowRatePerSecond = borrowRatePerSecond;
    }

    function setMarketActive(uint256 marketId, bool active) external onlyOwner {
        markets[marketId].params.active = active;
    }

    // --- View Functions ---

    function getPosition(uint256 marketId, address user) external view returns (uint256 collateral, uint256 debt) {
        Market storage m = markets[marketId];
        Position storage pos = positions[marketId][user];
        collateral = pos.collateralAmount;
        debt = _borrowShareToAmount(m, pos.borrowShares);
    }

    function getDepositBalance(uint256 marketId, address user) external view returns (uint256) {
        Market storage m = markets[marketId];
        if (m.totalShares == 0) return 0;
        return (depositShares[marketId][user] * m.totalDeposits) / m.totalShares;
    }

    function getAvailableLiquidity(uint256 marketId) external view returns (uint256) {
        Market storage m = markets[marketId];
        return m.totalDeposits - m.totalBorrows;
    }

    // --- Internal ---

    function _accrueInterest(Market storage m) internal {
        if (block.timestamp <= m.lastAccrualTimestamp || m.totalBorrows == 0) {
            m.lastAccrualTimestamp = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - m.lastAccrualTimestamp;
        uint256 interest = (m.totalBorrows * m.params.borrowRatePerSecond * elapsed) / PRECISION;

        m.totalBorrows += interest;
        m.totalDeposits += interest;
        m.borrowIndex += (m.borrowIndex * m.params.borrowRatePerSecond * elapsed) / PRECISION;
        m.lastAccrualTimestamp = block.timestamp;
    }

    function _isHealthy(Market storage m, Position storage pos) internal view returns (bool) {
        if (pos.borrowShares == 0) return true;

        uint256 debt = _borrowShareToAmount(m, pos.borrowShares);
        uint256 maxDebt = (pos.collateralAmount * m.params.liquidationThresholdBps) / BPS;
        return debt <= maxDebt;
    }

    function _toBorrowShares(Market storage m, uint256 amount) internal view returns (uint256) {
        if (m.totalBorrows == 0) return amount;
        return (amount * PRECISION) / m.borrowIndex;
    }

    function _borrowShareToAmount(Market storage m, uint256 shares) internal view returns (uint256) {
        return (shares * m.borrowIndex) / PRECISION;
    }
}