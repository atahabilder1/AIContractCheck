// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IFlashLoanProvider {
    event FlashLoan(address indexed borrower, address indexed asset, uint256 amount, uint256 fee, address indexed target, bytes data);
    event Deposit(address indexed depositor, address indexed asset, uint256 amount);
    event Withdraw(address indexed depositor, address indexed asset, uint256 amount);
    event FeeDistribution(address indexed asset, uint256 feeAccrued);

    function deposit(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function flashLoan(address asset, uint256 amount, address target, bytes calldata data) external;
    function flashLoanBatch(address[] calldata assets, uint256[] calldata amounts, address target, bytes calldata data) external;
    function getAssetBalance(address asset) external view returns (uint256);
    function getAssetTotalSupply(address asset) external view returns (uint256);
    function getAssetDepositBalance(address asset, address depositor) external view returns (uint256);
    function getAssetFeeAccrued(address asset) external view returns (uint256);
    function getAssetFeeRate(address asset) external view returns (uint256);
    function setAssetFeeRate(address asset, uint256 feeRate) external onlyOwner;
}

contract FlashLoanProvider is IFlashLoanProvider, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Mapping from asset address to its details
    struct AssetDetails {
        uint256 feeRate; // Fee rate in basis points (e.g., 30 for 0.30%)
        uint256 feeAccrued; // Total fees accrued for this asset
    }

    // Store asset details
    mapping(address => AssetDetails) public assetDetails;

    // Store total deposited amount for each asset
    mapping(address => uint256) public assetTotalDeposited;

    // Store individual depositor balances for each asset
    mapping(address => mapping(address => uint256)) public assetDepositorBalances;

    // Minimum flash loan amount for an asset
    mapping(address => uint256) public minFlashLoanAmount;

    // Callback function signature for flash loan execution
    interface IFlashLoanReceiver {
        function executeFlashLoan(address sender, address asset, uint256 amount, uint256 fee, bytes calldata data) external returns (bool);
        function executeFlashLoanBatch(address sender, address[] calldata assets, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata data) external returns (bool);
    }

    constructor() {
        // Set a default fee rate for ETH if needed, or handle it differently
        // For ERC20 tokens, the fee rate will be set by the owner.
    }

    modifier onlyValidAsset(address _asset) {
        require(_asset != address(0), "FlashLoanProvider: Invalid asset address");
        _;
    }

    modifier onlySufficientBalance(address _asset, uint256 _amount) {
        require(IERC20(_asset).balanceOf(address(this)) >= _amount, "FlashLoanProvider: Insufficient contract balance");
        _;
    }

    modifier onlyValidFlashLoanTarget(address _target) {
        require(_target != address(0), "FlashLoanProvider: Invalid flash loan target");
        _;
    }

    modifier onlyValidFlashLoanBatch(address[] calldata _assets, uint256[] calldata _amounts) {
        require(_assets.length > 0, "FlashLoanProvider: Empty assets array for batch");
        require(_assets.length == _amounts.length, "FlashLoanProvider: Mismatched assets and amounts arrays");
        _;
    }

    /**
     * @notice Deposits an ERC20 token into the pool.
     * @param asset The address of the ERC20 token to deposit.
     * @param amount The amount of the token to deposit.
     */
    function deposit(address asset, uint256 amount) external nonReentrant onlyValidAsset(asset) {
        require(amount > 0, "FlashLoanProvider: Deposit amount must be greater than zero");

        // Transfer the tokens from the user to the contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Update balances
        assetTotalDeposited[asset] = assetTotalDeposited[asset].checkedAdd(amount);
        assetDepositorBalances[asset][msg.sender] = assetDepositorBalances[asset][msg.sender].checkedAdd(amount);

        emit Deposit(msg.sender, asset, amount);
    }

    /**
     * @notice Withdraws an ERC20 token from the pool.
     * @param asset The address of the ERC20 token to withdraw.
     * @param amount The amount of the token to withdraw.
     */
    function withdraw(address asset, uint256 amount) external nonReentrant onlyValidAsset(asset) {
        require(amount > 0, "FlashLoanProvider: Withdraw amount must be greater than zero");
        require(assetDepositorBalances[asset][msg.sender] >= amount, "FlashLoanProvider: Insufficient depositor balance");

        // Calculate available balance considering potential flash loan liabilities
        uint256 availableBalance = assetTotalDeposited[asset];
        // This is a simplified check. A more robust implementation would track liabilities more precisely.
        // For now, we rely on the fact that flash loans must be repaid within the same transaction.
        // A more advanced system might involve reserve factors and more complex balance calculations.

        require(availableBalance >= amount, "FlashLoanProvider: Insufficient pool balance for withdrawal");

        // Update balances
        assetTotalDeposited[asset] = assetTotalDeposited[asset].checkedSub(amount);
        assetDepositorBalances[asset][msg.sender] = assetDepositorBalances[asset][msg.sender].checkedSub(amount);

        // Transfer the tokens to the user
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    /**
     * @notice Executes a single flash loan.
     * @param asset The address of the token to borrow.
     * @param amount The amount of the token to borrow.
     * @param target The address of the contract that will receive the loan and perform the callback.
     * @param data Additional data to pass to the target contract.
     */
    function flashLoan(address asset, uint256 amount, address target, bytes calldata data) external nonReentrant onlyValidAsset(asset) onlyValidFlashLoanTarget(target) onlySufficientBalance(asset, amount) {
        require(amount >= minFlashLoanAmount[asset], "FlashLoanProvider: Amount below minimum flash loan threshold");

        // Calculate fee
        uint256 feeRate = assetDetails[asset].feeRate;
        uint256 fee = (amount * feeRate) / 10000; // Fee in basis points (10000 = 100%)

        // Transfer the borrowed amount to the target
        IERC20(asset).safeTransfer(target, amount);

        // Execute the callback
        bool success = IFlashLoanReceiver(target).executeFlashLoan(msg.sender, asset, amount, fee, data);
        require(success, "FlashLoanProvider: Flash loan execution failed");

        // Repay the loan + fee
        uint256 totalRepayment = amount.checkedAdd(fee);
        IERC20(asset).safeTransferFrom(msg.sender, address(this), totalRepayment);

        // Accrue fees to depositors
        assetDetails[asset].feeAccrued = assetDetails[asset].feeAccrued.checkedAdd(fee);
        emit FeeDistribution(asset, fee);

        emit FlashLoan(msg.sender, asset, amount, fee, target, data);
    }

    /**
     * @notice Executes multiple flash loans in a single transaction.
     * @param assets An array of token addresses to borrow.
     * @param amounts An array of amounts to borrow for each token.
     * @param target The address of the contract that will receive the loans and perform the callback.
     * @param data Additional data to pass to the target contract.
     */
    function flashLoanBatch(address[] calldata assets, uint256[] calldata amounts, address target, bytes calldata data) external nonReentrant onlyValidFlashLoanTarget(target) onlyValidFlashLoanBatch(assets, amounts) {
        require(assets.length > 0, "FlashLoanProvider: No assets provided for batch flash loan");

        uint256 totalFee = 0;
        uint256[] memory fees = new uint256[](assets.length);
        address[] memory borrowedAssets = new address[](assets.length);
        uint256[] memory borrowedAmounts = new uint256[](assets.length);

        // Check contract balance for all requested loans first
        for (uint i = 0; i < assets.length; i++) {
            address asset = assets[i];
            uint256 amount = amounts[i];
            require(asset != address(0), "FlashLoanProvider: Invalid asset address in batch");
            require(amount > 0, "FlashLoanProvider: Zero amount in batch flash loan");
            require(amount >= minFlashLoanAmount[asset], "FlashLoanProvider: Amount below minimum flash loan threshold");
            require(IERC20(asset).balanceOf(address(this)) >= amount, "FlashLoanProvider: Insufficient contract balance for batch loan");

            uint256 feeRate = assetDetails[asset].feeRate;
            uint256 fee = (amount * feeRate) / 10000;
            fees[i] = fee;
            totalFee = totalFee.checkedAdd(fee);

            borrowedAssets[i] = asset;
            borrowedAmounts[i] = amount;
        }

        // Transfer all borrowed amounts to the target
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(target, amounts[i]);
        }

        // Execute the callback
        bool success = IFlashLoanReceiver(target).executeFlashLoanBatch(msg.sender, borrowedAssets, borrowedAmounts, fees, data);
        require(success, "FlashLoanProvider: Batch flash loan execution failed");

        // Repay all loans + fees
        for (uint i = 0; i < assets.length; i++) {
            uint256 totalRepayment = amounts[i].checkedAdd(fees[i]);
            IERC20(assets[i]).safeTransferFrom(msg.sender, address(this), totalRepayment);
            assetDetails[assets[i]].feeAccrued = assetDetails[assets[i]].feeAccrued.checkedAdd(fees[i]);
            emit FeeDistribution(assets[i], fees[i]);
        }

        emit FlashLoan(msg.sender, address(0), 0, totalFee, target, data); // asset and amount are 0 for batch
    }

    /**
     * @notice Gets the total balance of a specific asset in the pool.
     * @param asset The address of the asset.
     * @return The total balance of the asset.
     */
    function getAssetBalance(address asset) external view onlyValidAsset(asset) returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    /**
     * @notice Gets the total deposited amount for a specific asset.
     * @param asset The address of the asset.
     * @return The total deposited amount of the asset.
     */
    function getAssetTotalSupply(address asset) external view onlyValidAsset(asset) returns (uint256) {
        return assetTotalDeposited[asset];
    }

    /**
     * @notice Gets the deposited balance of a specific asset for a given depositor.
     * @param asset The address of the asset.
     * @param depositor The address of the depositor.
     * @return The deposited balance of the asset for the depositor.
     */
    function getAssetDepositBalance(address asset, address depositor) external view onlyValidAsset(asset) returns (uint256) {
        return assetDepositorBalances[asset][depositor];
    }

    /**
     * @notice Gets the total fees accrued for a specific asset.
     * @param asset The address of the asset.
     * @return The total accrued fees for the asset.
     */
    function getAssetFeeAccrued(address asset) external view onlyValidAsset(asset) returns (uint256) {
        return assetDetails[asset].feeAccrued;
    }

    /**
     * @notice Gets the current fee rate for a specific asset.
     * @param asset The address of the asset.
     * @return The fee rate in basis points.
     */
    function getAssetFeeRate(address asset) external view onlyValidAsset(asset) returns (uint256) {
        return assetDetails[asset].feeRate;
    }

    /**
     * @notice Sets the fee rate for a specific asset. Only callable by the owner.
     * @param asset The address of the asset.
     * @param feeRate The new fee rate in basis points (e.g., 30 for 0.30%).
     */
    function setAssetFeeRate(address asset, uint256 feeRate) external onlyOwner onlyValidAsset(asset) {
        require(feeRate <= 10000, "FlashLoanProvider: Fee rate cannot exceed 100%"); // Max 100% fee
        assetDetails[asset].feeRate = feeRate;
    }

    /**
     * @notice Sets the minimum flash loan amount for a specific asset. Only callable by the owner.
     * @param asset The address of the asset.
     * @param minAmount The minimum amount for flash loans.
     */
    function setMinFlashLoanAmount(address asset, uint256 minAmount) external onlyOwner onlyValidAsset(asset) {
        minFlashLoanAmount[asset] = minAmount;
    }

    // Fallback function to receive Ether if the contract is intended to handle ETH directly.
    // Note: Flash loans typically operate on ERC20 tokens. Handling ETH would require
    // specific logic for WETH conversion or direct ETH transfers, which adds complexity.
    // This example focuses on ERC20 tokens.
    receive() external payable {}
}