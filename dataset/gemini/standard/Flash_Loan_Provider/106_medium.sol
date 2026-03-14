// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFlashLoanProvider {
    event LoanRepaid(address indexed borrower, address indexed asset, uint256 amount);
    event LoanTaken(address indexed borrower, address indexed asset, uint256 amount);

    function takeLoan(address asset, uint256 amount, address callbackContract) external returns (bool);
    function repayLoan(address asset, uint256 amount) external;

    function getFeePercentage(address asset) external view returns (uint256);
    function setFeePercentage(address asset, uint256 feePercentage) external onlyOwner;

    function getSupportedAssets() external view returns (address[] memory);
    function addSupportedAsset(address asset) external onlyOwner;
    function removeSupportedAsset(address asset) external onlyOwner;

    function getLoanDetails(address borrower, address asset) external view returns (uint256, uint256); // amount, fee
}

contract FlashLoanProvider is IFlashLoanProvider, Ownable {
    using SafeERC20 for IERC20;

    struct Loan {
        uint256 amount;
        uint256 fee;
    }

    // mapping from asset address to its fee percentage (basis points)
    mapping(address => uint256) public feePercentage;
    // mapping from asset address to a boolean indicating if it's supported
    mapping(address => bool) public isSupportedAsset;
    // mapping from borrower address to a mapping of asset address to their loan details
    mapping(address => mapping(address => Loan)) public loans;
    // array of supported asset addresses
    address[] public supportedAssets;

    // --- Events ---
    event LoanRepaid(address indexed borrower, address indexed asset, uint256 amount);
    event LoanTaken(address indexed borrower, address indexed asset, uint256 amount);

    // --- Constructor ---
    constructor() {
        // Owner is the deployer of the contract
    }

    // --- Public Functions ---

    /**
     * @notice Allows a borrower to take a flash loan.
     * @param asset The address of the ERC20 token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param callbackContract The address of the contract that will receive the borrowed tokens and execute logic.
     * @return success A boolean indicating whether the loan was successfully taken.
     */
    function takeLoan(address asset, uint256 amount, address callbackContract) external override returns (bool) {
        require(isSupportedAsset[asset], "Asset not supported");
        require(amount > 0, "Amount must be greater than zero");

        // Transfer assets from the provider's balance to the callback contract
        IERC20(asset).safeTransfer(callbackContract, amount);

        // Store loan details
        uint256 fee = (amount * feePercentage[asset]) / 10000; // Fee is in basis points (1/10000)
        loans[msg.sender][asset] = Loan({
            amount: amount,
            fee: fee
        });

        emit LoanTaken(msg.sender, asset, amount);
        return true;
    }

    /**
     * @notice Allows a borrower to repay a flash loan. This function is typically called by the callback contract.
     * @param asset The address of the ERC20 token to repay.
     * @param amount The total amount to repay (principal + fee).
     */
    function repayLoan(address asset, uint256 amount) external override {
        require(loans[msg.sender][asset].amount > 0, "No active loan for this asset");

        uint256 principal = loans[msg.sender][asset].amount;
        uint256 fee = loans[msg.sender][asset].fee;
        uint256 totalRepayment = principal + fee;

        require(amount >= totalRepayment, "Insufficient repayment amount");

        // Transfer the repayment amount from the borrower's allowance to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Clear loan details
        delete loans[msg.sender][asset];

        emit LoanRepaid(msg.sender, asset, totalRepayment);
    }

    // --- Fee Management Functions ---

    /**
     * @notice Gets the current fee percentage for a given asset.
     * @param asset The address of the ERC20 token.
     * @return feePercentage The fee percentage in basis points.
     */
    function getFeePercentage(address asset) external view override returns (uint256) {
        return feePercentage[asset];
    }

    /**
     * @notice Sets the fee percentage for a given asset. Only callable by the owner.
     * @param asset The address of the ERC20 token.
     * @param feePercentage The new fee percentage in basis points (e.g., 30 for 0.3%).
     */
    function setFeePercentage(address asset, uint256 feePercentage_) external override onlyOwner {
        require(feePercentage_ <= 10000, "Fee percentage cannot exceed 100%"); // Max 100% fee
        feePercentage[asset] = feePercentage_;
    }

    // --- Asset Management Functions ---

    /**
     * @notice Gets a list of all supported asset addresses.
     * @return supportedAssets An array of supported asset addresses.
     */
    function getSupportedAssets() external view override returns (address[] memory) {
        return supportedAssets;
    }

    /**
     * @notice Adds a new asset to the list of supported assets. Only callable by the owner.
     * @param asset The address of the ERC20 token to add.
     */
    function addSupportedAsset(address asset) external override onlyOwner {
        require(asset != address(0), "Invalid asset address");
        require(!isSupportedAsset[asset], "Asset already supported");

        isSupportedAsset[asset] = true;
        supportedAssets.push(asset);
    }

    /**
     * @notice Removes an asset from the list of supported assets. Only callable by the owner.
     * @param asset The address of the ERC20 token to remove.
     */
    function removeSupportedAsset(address asset) external override onlyOwner {
        require(isSupportedAsset[asset], "Asset not supported");

        isSupportedAsset[asset] = false;

        // Remove from the array (efficiently by swapping with the last element and popping)
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                supportedAssets[i] = supportedAssets[supportedAssets.length - 1];
                supportedAssets.pop();
                break;
            }
        }
    }

    // --- Loan Details ---

    /**
     * @notice Retrieves the loan details for a specific borrower and asset.
     * @param borrower The address of the borrower.
     * @param asset The address of the asset.
     * @return amount The borrowed amount.
     * @return fee The calculated fee for the loan.
     */
    function getLoanDetails(address borrower, address asset) external view override returns (uint256, uint256) {
        Loan storage loan = loans[borrower][asset];
        return (loan.amount, loan.fee);
    }

    // --- Fallback and Receive ---
    // This contract does not expect to receive Ether directly.

    // --- Internal Functions ---
    // No internal functions needed for this basic implementation.

    // --- Modifier ---
    // Ownable modifier is used for owner-only functions.
}