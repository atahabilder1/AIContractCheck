// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Lending Protocol with Variable Interest Rates
contract VariableRateLending {
    address public owner;

    struct Market {
        address token;
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 baseRate;          // Base interest rate (e.g., 2%)
        uint256 multiplier;         // Rate multiplier based on utilization
        uint256 jumpMultiplier;     // Higher multiplier after kink
        uint256 kink;              // Utilization rate where jump kicks in (e.g., 80%)
        uint256 reserveFactor;     // Portion of interest to reserves
        uint256 lastUpdateBlock;
        uint256 borrowIndex;
        uint256 depositIndex;
    }

    struct UserDeposit {
        uint256 principal;
        uint256 depositIndex;
    }

    struct UserBorrow {
        uint256 principal;
        uint256 borrowIndex;
    }

    mapping(address => Market) public markets;
    mapping(address => mapping(address => UserDeposit)) public deposits;
    mapping(address => mapping(address => UserBorrow)) public borrows;
    mapping(address => mapping(address => uint256)) public collateral;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BLOCKS_PER_YEAR = 2_102_400;

    event Deposit(address indexed token, address indexed user, uint256 amount);
    event Withdraw(address indexed token, address indexed user, uint256 amount);
    event Borrow(address indexed token, address indexed user, uint256 amount);
    event Repay(address indexed token, address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createMarket(
        address token,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 kink,
        uint256 reserveFactor
    ) external onlyOwner {
        require(markets[token].token == address(0), "Market exists");

        markets[token] = Market({
            token: token,
            totalDeposits: 0,
            totalBorrows: 0,
            baseRate: baseRate,
            multiplier: multiplier,
            jumpMultiplier: jumpMultiplier,
            kink: kink,
            reserveFactor: reserveFactor,
            lastUpdateBlock: block.number,
            borrowIndex: PRECISION,
            depositIndex: PRECISION
        });
    }

    function getUtilizationRate(address token) public view returns (uint256) {
        Market storage market = markets[token];
        if (market.totalDeposits == 0) return 0;
        return market.totalBorrows * PRECISION / market.totalDeposits;
    }

    function getBorrowRate(address token) public view returns (uint256) {
        Market storage market = markets[token];
        uint256 utilization = getUtilizationRate(token);

        if (utilization <= market.kink) {
            return market.baseRate + (utilization * market.multiplier / PRECISION);
        } else {
            uint256 normalRate = market.baseRate + (market.kink * market.multiplier / PRECISION);
            uint256 excessUtil = utilization - market.kink;
            return normalRate + (excessUtil * market.jumpMultiplier / PRECISION);
        }
    }

    function getDepositRate(address token) public view returns (uint256) {
        Market storage market = markets[token];
        uint256 borrowRate = getBorrowRate(token);
        uint256 utilization = getUtilizationRate(token);
        return borrowRate * utilization * (PRECISION - market.reserveFactor) / PRECISION / PRECISION;
    }

    function accrueInterest(address token) public {
        Market storage market = markets[token];
        uint256 blockDelta = block.number - market.lastUpdateBlock;
        if (blockDelta == 0) return;

        uint256 borrowRate = getBorrowRate(token);
        uint256 interestFactor = borrowRate * blockDelta / BLOCKS_PER_YEAR;

        uint256 interestAccumulated = market.totalBorrows * interestFactor / PRECISION;
        market.totalBorrows += interestAccumulated;
        market.borrowIndex += market.borrowIndex * interestFactor / PRECISION;

        uint256 depositInterest = interestAccumulated * (PRECISION - market.reserveFactor) / PRECISION;
        market.totalDeposits += depositInterest;
        market.depositIndex += market.depositIndex * depositInterest / (market.totalDeposits - depositInterest) / PRECISION;

        market.lastUpdateBlock = block.number;
    }

    function deposit(address token, uint256 amount) external {
        accrueInterest(token);
        Market storage market = markets[token];
        require(market.token != address(0), "Market not found");

        deposits[token][msg.sender].principal += amount;
        deposits[token][msg.sender].depositIndex = market.depositIndex;
        market.totalDeposits += amount;

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Deposit(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external {
        accrueInterest(token);
        Market storage market = markets[token];

        uint256 balance = getDepositBalance(token, msg.sender);
        require(balance >= amount, "Insufficient balance");

        deposits[token][msg.sender].principal = balance - amount;
        deposits[token][msg.sender].depositIndex = market.depositIndex;
        market.totalDeposits -= amount;

        IERC20(token).transfer(msg.sender, amount);
        emit Withdraw(token, msg.sender, amount);
    }

    function getDepositBalance(address token, address user) public view returns (uint256) {
        UserDeposit storage userDeposit = deposits[token][user];
        if (userDeposit.depositIndex == 0) return 0;
        Market storage market = markets[token];
        return userDeposit.principal * market.depositIndex / userDeposit.depositIndex;
    }

    function getBorrowBalance(address token, address user) public view returns (uint256) {
        UserBorrow storage userBorrow = borrows[token][user];
        if (userBorrow.borrowIndex == 0) return 0;
        Market storage market = markets[token];
        return userBorrow.principal * market.borrowIndex / userBorrow.borrowIndex;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
