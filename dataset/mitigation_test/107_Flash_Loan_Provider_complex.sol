// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

contract FlashLoanProvider is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Pool {
        uint256 totalSupply;
        uint256 totalBorrowed;
        uint256 accumulatedFees;
        uint256 lastUpdateTimestamp;
        bool isActive;
    }

    struct UserBalance {
        uint256 balance;
        uint256 rewardDebt;
    }

    mapping(address => Pool) public pools;
    mapping(address => mapping(address => UserBalance)) public userBalances;
    mapping(address => bool) public authorizedCallers;

    uint256 public constant FLASH_LOAN_FEE_PERCENTAGE = 9; // 0.09%
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant MAX_FLASH_LOAN_ASSETS = 10;

    event FlashLoan(
        address indexed receiver,
        address indexed initiator,
        address[] assets,
        uint256[] amounts,
        uint256[] premiums
    );

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event PoolAdded(address indexed asset);
    event PoolStatusChanged(address indexed asset, bool isActive);

    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validAsset(address asset) {
        require(asset != address(0), "Invalid asset address");
        require(pools[asset].isActive, "Pool not active");
        _;
    }

    modifier validArrays(address[] memory assets, uint256[] memory amounts) {
        require(assets.length == amounts.length, "Arrays length mismatch");
        require(assets.length > 0 && assets.length <= MAX_FLASH_LOAN_ASSETS, "Invalid array length");
        _;
    }

    constructor() {}

    function addPool(address asset) external onlyOwner {
        require(asset != address(0), "Invalid asset address");
        require(!pools[asset].isActive, "Pool already exists");

        pools[asset] = Pool({
            totalSupply: 0,
            totalBorrowed: 0,
            accumulatedFees: 0,
            lastUpdateTimestamp: block.timestamp,
            isActive: true
        });

        emit PoolAdded(asset);
    }

    function setPoolStatus(address asset, bool isActive) external onlyOwner {
        require(asset != address(0), "Invalid asset address");
        require(pools[asset].lastUpdateTimestamp > 0, "Pool does not exist");

        pools[asset].isActive = isActive;
        emit PoolStatusChanged(asset, isActive);
    }

    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        require(caller != address(0), "Invalid caller address");
        authorizedCallers[caller] = authorized;
    }

    function deposit(address asset, uint256 amount) external nonReentrant validAsset(asset) {
        require(amount > 0, "Amount must be greater than 0");

        _updatePool(asset);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        Pool storage pool = pools[asset];
        UserBalance storage userBalance = userBalances[asset][msg.sender];

        // Update user's reward debt based on current accumulated fees
        if (userBalance.balance > 0) {
            uint256 pendingReward = _calculatePendingReward(asset, msg.sender);
            userBalance.rewardDebt = userBalance.rewardDebt.add(pendingReward);
        }

        userBalance.balance = userBalance.balance.add(amount);
        pool.totalSupply = pool.totalSupply.add(amount);

        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant validAsset(asset) {
        require(amount > 0, "Amount must be greater than 0");

        UserBalance storage userBalance = userBalances[asset][msg.sender];
        require(userBalance.balance >= amount, "Insufficient balance");

        _updatePool(asset);

        Pool storage pool = pools[asset];
        require(pool.totalSupply.sub(pool.totalBorrowed) >= amount, "Insufficient liquidity");

        // Calculate and transfer pending rewards
        uint256 pendingReward = _calculatePendingReward(asset, msg.sender);
        if (pendingReward > 0) {
            userBalance.rewardDebt = userBalance.rewardDebt.add(pendingReward);
            IERC20(asset).safeTransfer(msg.sender, pendingReward);
        }

        userBalance.balance = userBalance.balance.sub(amount);
        pool.totalSupply = pool.totalSupply.sub(amount);

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata params
    ) external nonReentrant validArrays(assets, amounts) {
        require(receiverAddress != address(0), "Invalid receiver address");

        uint256[] memory premiums = new uint256[](assets.length);
        uint256[] memory balancesBefore = new uint256[](assets.length);

        // Validate assets and calculate premiums
        for (uint256 i = 0; i < assets.length; i++) {
            require(pools[assets[i]].isActive, "Pool not active");
            require(amounts[i] > 0, "Amount must be greater than 0");

            Pool storage pool = pools[assets[i]];
            require(pool.totalSupply.sub(pool.totalBorrowed) >= amounts[i], "Insufficient liquidity");

            premiums[i] = amounts[i].mul(FLASH_LOAN_FEE_PERCENTAGE).div(FEE_PRECISION);
            balancesBefore[i] = IERC20(assets[i]).balanceOf(address(this));

            // Update pool state
            _updatePool(assets[i]);
            pool.totalBorrowed = pool.totalBorrowed.add(amounts[i]);
        }

        // Transfer assets to receiver
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(receiverAddress, amounts[i]);
        }

        // Execute callback
        require(
            IFlashLoanReceiver(receiverAddress).executeOperation(
                assets,
                amounts,
                premiums,
                msg.sender,
                params
            ),
            "Flash loan execution failed"
        );

        // Verify repayment and collect fees
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 balanceAfter = IERC20(assets[i]).balanceOf(address(this));
            uint256 expectedBalance = balancesBefore[i].add(premiums[i]);

            require(balanceAfter >= expectedBalance, "Flash loan not repaid");

            Pool storage pool = pools[assets[i]];
            pool.totalBorrowed = pool.totalBorrowed.sub(amounts[i]);
            pool.accumulatedFees = pool.accumulatedFees.add(premiums[i]);
        }

        emit FlashLoan(receiverAddress, msg.sender, assets, amounts, premiums);
    }

    function getPoolInfo(address asset) external view returns (
        uint256 totalSupply,
        uint256 totalBorrowed,
        uint256 accumulatedFees,
        uint256 availableLiquidity,
        bool isActive
    ) {
        Pool memory pool = pools[asset];
        return (
            pool.totalSupply,
            pool.totalBorrowed,
            pool.accumulatedFees,
            pool.totalSupply.sub(pool.totalBorrowed),
            pool.isActive
        );
    }

    function getUserBalance(address asset, address user) external view returns (uint256) {
        return userBalances[asset][user].balance;
    }

    function getPendingRewards(address asset, address user) external view returns (uint256) {
        return _calculatePendingReward(asset, user);
    }

    function getFlashLoanFee(uint256 amount) external pure returns (uint256) {
        return amount.mul(FLASH_LOAN_FEE_PERCENTAGE).div(FEE_PRECISION);
    }

    function _updatePool(address asset) internal {
        Pool storage pool = pools[asset];
        pool.lastUpdateTimestamp = block.timestamp;
    }

    function _calculatePendingReward(address asset, address user) internal view returns (uint256) {
        Pool memory pool = pools[asset];
        UserBalance memory userBalance = userBalances[asset][user];

        if (pool.totalSupply == 0 || userBalance.balance == 0) {
            return 0;
        }

        uint256 userShare = userBalance.balance.mul(1e18).div(pool.totalSupply);
        uint256 totalReward = pool.accumulatedFees.mul(userShare).div(1e18);

        return totalReward > userBalance.rewardDebt ? totalReward.sub(userBalance.rewardDebt) : 0;
    }

    function emergencyWithdraw(address asset, uint256 amount) external onlyOwner {
        require(asset != address(0), "Invalid asset address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(asset).safeTransfer(owner(), amount);
    }
}