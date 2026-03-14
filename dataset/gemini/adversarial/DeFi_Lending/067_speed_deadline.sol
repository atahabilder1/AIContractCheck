// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SimpleLending is Ownable {
    using SafeMath for uint256;

    // Mapping of asset address to its lending pool
    mapping(address => LendingPool) public lendingPools;

    // Represents a pool for a specific ERC20 token
    struct LendingPool {
        IERC20 asset;
        uint256 totalSupplied;
        uint256 totalBorrowed;
        uint256 interestRate; // In basis points (e.g., 500 for 5%)
        mapping(address => uint256) suppliers; // User address => amount supplied
        mapping(address => uint256) borrowers; // User address => amount borrowed
    }

    // Event for depositing assets
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    // Event for withdrawing assets
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    // Event for borrowing assets
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    // Event for repaying borrowed assets
    event Repay(address indexed user, address indexed asset, uint256 amount);

    /**
     * @notice Initializes a new lending pool for a given ERC20 token.
     * @param _asset The address of the ERC20 token.
     * @param _initialInterestRate The initial interest rate in basis points.
     */
    function createLendingPool(address _asset, uint256 _initialInterestRate) public onlyOwner {
        require(_asset != address(0), "Invalid asset address");
        require(lendingPools[_asset].asset == address(0), "Pool already exists for this asset");

        lendingPools[_asset] = LendingPool({
            asset: IERC20(_asset),
            totalSupplied: 0,
            totalBorrowed: 0,
            interestRate: _initialInterestRate
        });
    }

    /**
     * @notice Updates the interest rate for a lending pool.
     * @param _asset The asset address of the lending pool.
     * @param _newInterestRate The new interest rate in basis points.
     */
    function updateInterestRate(address _asset, uint256 _newInterestRate) public onlyOwner {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        lendingPools[_asset].interestRate = _newInterestRate;
    }

    /**
     * @notice Deposits ERC20 tokens into a lending pool.
     * @param _asset The asset address to deposit.
     * @param _amount The amount of tokens to deposit.
     */
    function deposit(address _asset, uint256 _amount) public {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        require(_amount > 0, "Amount must be greater than zero");

        IERC20 assetToken = lendingPools[_asset].asset;
        require(assetToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        lendingPools[_asset].suppliers[msg.sender] = lendingPools[_asset].suppliers[msg.sender].add(_amount);
        lendingPools[_asset].totalSupplied = lendingPools[_asset].totalSupplied.add(_amount);

        emit Deposit(msg.sender, _asset, _amount);
    }

    /**
     * @notice Withdraws ERC20 tokens from a lending pool.
     * @param _asset The asset address to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(address _asset, uint256 _amount) public {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        require(_amount > 0, "Amount must be greater than zero");

        uint256 userSupplied = lendingPools[_asset].suppliers[msg.sender];
        require(userSupplied >= _amount, "Insufficient supplied amount");

        // Ensure that withdrawal doesn't exceed available liquidity after considering borrows
        uint256 availableLiquidity = lendingPools[_asset].totalSupplied.sub(lendingPools[_asset].totalBorrowed);
        require(availableLiquidity >= _amount, "Insufficient liquidity to withdraw");

        lendingPools[_asset].suppliers[msg.sender] = userSupplied.sub(_amount);
        lendingPools[_asset].totalSupplied = lendingPools[_asset].totalSupplied.sub(_amount);

        IERC20 assetToken = lendingPools[_asset].asset;
        require(assetToken.transfer(msg.sender, _amount), "Transfer failed");

        emit Withdraw(msg.sender, _asset, _amount);
    }

    /**
     * @notice Borrows ERC20 tokens from a lending pool.
     * @param _asset The asset address to borrow.
     * @param _amount The amount of tokens to borrow.
     */
    function borrow(address _asset, uint256 _amount) public {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        require(_amount > 0, "Amount must be greater than zero");

        // Basic collateralization check (for simplicity, assuming user has supplied enough)
        // In a real DeFi, this would involve calculating collateral value and borrow limits
        uint256 userSupplied = lendingPools[_asset].suppliers[msg.sender];
        // For this hackathon version, we'll simplify and assume a 1:1 collateral ratio.
        // A more robust system would require a separate collateral mechanism.
        // For now, we'll just check if the user has *any* supplied assets.
        require(userSupplied > 0, "You must supply assets to borrow");

        uint256 availableLiquidity = lendingPools[_asset].totalSupplied.sub(lendingPools[_asset].totalBorrowed);
        require(availableLiquidity >= _amount, "Insufficient liquidity to borrow");

        // In a real system, interest calculation would be more complex and time-dependent.
        // For simplicity, we'll just update totalBorrowed and assume repayment includes interest.
        lendingPools[_asset].totalBorrowed = lendingPools[_asset].totalBorrowed.add(_amount);
        lendingPools[_asset].borrowers[msg.sender] = lendingPools[_asset].borrowers[msg.sender].add(_amount);

        IERC20 assetToken = lendingPools[_asset].asset;
        require(assetToken.transfer(msg.sender, _amount), "Transfer failed");

        emit Borrow(msg.sender, _asset, _amount);
    }

    /**
     * @notice Repays borrowed ERC20 tokens.
     * @param _asset The asset address to repay.
     * @param _amount The amount of tokens to repay.
     */
    function repay(address _asset, uint256 _amount) public {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        require(_amount > 0, "Amount must be greater than zero");

        uint256 userBorrowed = lendingPools[_asset].borrowers[msg.sender];
        require(userBorrowed > 0, "You have no active debt for this asset");

        // Calculate the actual amount to repay, considering interest.
        // For this hackathon version, we'll assume the user repays the borrowed amount + a simple interest calculation.
        // A real system would track borrow timestamps and use a more accurate interest accrual.
        uint256 interestRate = lendingPools[_asset].interestRate;
        // Simple interest calculation for demonstration: amount * interestRate / 10000
        // This is a very basic approximation and not how real DeFi interest works.
        uint256 calculatedInterest = _amount.mul(interestRate).div(10000); // This is not how interest accrues over time!
        uint256 totalRepayAmount = _amount.add(calculatedInterest); // This is also not correct.

        // For simplicity in this hackathon version, we'll just require the user to repay AT LEAST the borrowed amount.
        // The actual interest calculation and accrual is complex and time-dependent.
        // We'll enforce that the amount repaid is enough to cover the principal borrowed.
        require(_amount >= userBorrowed, "Repayment amount must be at least the borrowed principal");

        IERC20 assetToken = lendingPools[_asset].asset;
        require(assetToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        uint256 amountToReduceFromDebt = _amount;
        if (amountToReduceFromDebt > userBorrowed) {
            amountToReduceFromDebt = userBorrowed;
        }
        lendingPools[_asset].borrowers[msg.sender] = userBorrowed.sub(amountToReduceFromDebt);
        lendingPools[_asset].totalBorrowed = lendingPools[_asset].totalBorrowed.sub(amountToReduceFromDebt);

        // If the user repays more than they borrowed, the excess can be considered interest payment.
        // In a real system, this would be handled more precisely.
        emit Repay(msg.sender, _asset, _amount);
    }

    /**
     * @notice Gets the current interest rate for a lending pool.
     * @param _asset The asset address of the lending pool.
     * @return The interest rate in basis points.
     */
    function getInterestRate(address _asset) public view returns (uint256) {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        return lendingPools[_asset].interestRate;
    }

    /**
     * @notice Gets the amount of an asset a user has supplied.
     * @param _asset The asset address.
     * @param _user The user's address.
     * @return The amount supplied by the user.
     */
    function getUserSuppliedAmount(address _asset, address _user) public view returns (uint256) {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        return lendingPools[_asset].suppliers[_user];
    }

    /**
     * @notice Gets the amount of an asset a user has borrowed.
     * @param _asset The asset address.
     * @param _user The user's address.
     * @return The amount borrowed by the user.
     */
    function getUserBorrowedAmount(address _asset, address _user) public view returns (uint256) {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        return lendingPools[_asset].borrowers[_user];
    }

    /**
     * @notice Gets the total supplied amount for an asset.
     * @param _asset The asset address.
     * @return The total amount supplied for the asset.
     */
    function getTotalSupplied(address _asset) public view returns (uint256) {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        return lendingPools[_asset].totalSupplied;
    }

    /**
     * @notice Gets the total borrowed amount for an asset.
     * @param _asset The asset address.
     * @return The total amount borrowed for the asset.
     */
    function getTotalBorrowed(address _asset) public view returns (uint256) {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        return lendingPools[_asset].totalBorrowed;
    }

    /**
     * @notice Gets the available liquidity for an asset.
     * @param _asset The asset address.
     * @return The available liquidity for the asset.
     */
    function getAvailableLiquidity(address _asset) public view returns (uint256) {
        require(lendingPools[_asset].asset != address(0), "Pool does not exist");
        return lendingPools[_asset].totalSupplied.sub(lendingPools[_asset].totalBorrowed);
    }
}