// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CollateralLending is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // --- State Variables ---
    IERC20 public stablecoin; // The stablecoin to be borrowed
    uint256 public collateralRatio; // Minimum collateral to debt ratio (e.g., 150 for 150%)
    uint256 public liquidationPenalty; // Penalty for liquidation (e.g., 5 for 5%)
    uint256 public liquidationThreshold; // Collateral ratio below which liquidation is triggered

    // Mapping to store user collateral and debt
    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userDebt;

    // --- Events ---
    event DepositCollateral(address indexed user, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);
    event BorrowStablecoin(address indexed user, uint256 amount);
    event RepayStablecoin(address indexed user, uint256 amount);
    event Liquidation(address indexed liquidatedUser, address indexed liquidator, uint256 collateralLiquidated, uint256 debtRepaid);

    // --- Errors ---
    error InsufficientCollateralRatio();
    error InsufficientCollateral();
    error ExceedsBorrowLimit();
    error InsufficientStablecoinBalance();
    error NotEnoughCollateralToWithdraw();
    error ZeroAmount();
    error InvalidCollateralRatio();
    error InvalidLiquidationPenalty();
    error InvalidLiquidationThreshold();

    // --- Constructor ---
    constructor(address _stablecoinAddress, uint256 _collateralRatio, uint256 _liquidationPenalty, uint256 _liquidationThreshold) {
        stablecoin = IERC20(_stablecoinAddress);
        // Ensure valid inputs
        if (_collateralRatio == 0) revert InvalidCollateralRatio();
        if (_liquidationPenalty >= 100) revert InvalidLiquidationPenalty(); // Penalty should be less than 100%
        if (_liquidationThreshold == 0) revert InvalidLiquidationThreshold();
        if (_liquidationThreshold >= _collateralRatio) revert InvalidLiquidationThreshold();


        collateralRatio = _collateralRatio;
        liquidationPenalty = _liquidationPenalty;
        liquidationThreshold = _liquidationThreshold;
    }

    // --- Modifiers ---
    modifier onlyValidCollateralRatio(uint256 _collateral, uint256 _debt) {
        // ETH price is assumed to be 1 for simplicity in this basic example.
        // In a real-world scenario, an oracle would be needed to get the ETH price.
        uint256 currentCollateralRatio = _collateral.mul(100).div(_debt == 0 ? 1 : _debt); // Avoid division by zero
        if (currentCollateralRatio < collateralRatio) {
            revert InsufficientCollateralRatio();
        }
        _;
    }

    // --- Functions ---

    // Deposit ETH as collateral
    // Note: This contract only accepts ETH. For ERC20 collateral, the contract would need to be modified.
    receive() external payable {
        depositCollateral();
    }

    function depositCollateral() public payable {
        require(msg.value > 0, "Amount must be greater than zero.");
        userCollateral[msg.sender] = userCollateral[msg.sender].add(msg.value);
        emit DepositCollateral(msg.sender, msg.value);
    }

    // Withdraw ETH collateral
    function withdrawCollateral(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");
        uint256 currentCollateral = userCollateral[msg.sender];
        uint256 currentDebt = userDebt[msg.sender];

        // Ensure withdrawing doesn't violate the minimum collateral ratio
        if (currentCollateral.sub(_amount) < currentDebt.mul(liquidationThreshold).div(100)) {
            revert NotEnoughCollateralToWithdraw();
        }

        userCollateral[msg.sender] = currentCollateral.sub(_amount);
        payable(msg.sender).transfer(_amount);
        emit WithdrawCollateral(msg.sender, _amount);
    }

    // Borrow stablecoin
    function borrowStablecoin(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");

        uint256 currentCollateral = userCollateral[msg.sender];
        uint256 currentDebt = userDebt[msg.sender];

        // Check if the borrow amount exceeds the allowed limit based on collateral
        // For simplicity, we assume ETH price is 1.
        // Max borrowable amount = (collateral * 100) / collateralRatio - currentDebt
        uint256 maxBorrowable = currentCollateral.mul(100).div(collateralRatio);
        if (maxBorrowable < currentDebt.add(_amount)) {
            revert ExceedsBorrowLimit();
        }

        // Check if the stablecoin contract has enough balance to transfer
        if (stablecoin.balanceOf(address(this)) < _amount) {
            revert InsufficientStablecoinBalance();
        }

        userDebt[msg.sender] = currentDebt.add(_amount);
        stablecoin.safeTransfer(msg.sender, _amount);
        emit BorrowStablecoin(msg.sender, _amount);
    }

    // Repay stablecoin debt
    function repayStablecoin(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");

        uint256 currentDebt = userDebt[msg.sender];
        require(currentDebt >= _amount, "Repayment amount exceeds current debt.");

        // Transfer stablecoin from user to this contract
        stablecoin.safeTransferFrom(msg.sender, address(this), _amount);

        userDebt[msg.sender] = currentDebt.sub(_amount);
        emit RepayStablecoin(msg.sender, _amount);
    }

    // Liquidate a user's collateral if their collateral ratio drops below the threshold
    function liquidate(address _userToLiquidate) public {
        uint256 collateralToLiquidate = userCollateral[_userToLiquidate];
        uint256 debtToRepay = userDebt[_userToLiquidate];

        // Assume ETH price is 1 for simplicity.
        // Check if collateral is insufficient for liquidation
        if (collateralToLiquidate.mul(100).div(debtToRepay == 0 ? 1 : debtToRepay) >= liquidationThreshold) {
            revert InsufficientCollateral(); // User's collateral is still healthy
        }

        // Calculate the amount of debt to repay and collateral to liquidate
        // The liquidator repays the debt and takes a portion of the collateral as a penalty
        uint256 stablecoinToRepay = debtToRepay; // Liquidator repays the entire debt for simplicity
        uint256 collateralToTake = collateralToLiquidate.mul(liquidationPenalty).div(100); // Penalty portion

        // Ensure the contract has enough stablecoin to repay the debt
        if (stablecoin.balanceOf(address(this)) < stablecoinToRepay) {
            revert InsufficientStablecoinBalance();
        }

        // Transfer stablecoin from the contract to the liquidator (to repay the debt)
        stablecoin.safeTransfer(msg.sender, stablecoinToRepay);

        // Transfer collateral to the liquidator (with penalty)
        userCollateral[_userToLiquidate] = collateralToLiquidate.sub(collateralToTake);
        payable(_userToLiquidate).transfer(collateralToTake); // Send collateral back to the liquidated user (after penalty)

        // Update debt for the liquidated user
        userDebt[_userToLiquidate] = 0;

        emit Liquidation(_userToLiquidate, msg.sender, collateralToTake, stablecoinToRepay);
    }

    // --- Admin Functions ---

    // Update collateral ratio
    function setCollateralRatio(uint256 _newCollateralRatio) public onlyOwner {
        if (_newCollateralRatio == 0) revert InvalidCollateralRatio();
        collateralRatio = _newCollateralRatio;
    }

    // Update liquidation penalty
    function setLiquidationPenalty(uint256 _newLiquidationPenalty) public onlyOwner {
        if (_newLiquidationPenalty >= 100) revert InvalidLiquidationPenalty();
        liquidationPenalty = _newLiquidationPenalty;
    }

    // Update liquidation threshold
    function setLiquidationThreshold(uint256 _newLiquidationThreshold) public onlyOwner {
        if (_newLiquidationThreshold == 0) revert InvalidLiquidationThreshold();
        if (_newLiquidationThreshold >= collateralRatio) revert InvalidLiquidationThreshold();
        liquidationThreshold = _newLiquidationThreshold;
    }

    // Owner can withdraw any stablecoin mistakenly sent to the contract
    function withdrawStuckStablecoin(uint256 _amount) public onlyOwner {
        stablecoin.safeTransfer(owner(), _amount);
    }

    // Owner can withdraw any ETH mistakenly sent to the contract
    function withdrawStuckETH(uint256 _amount) public onlyOwner {
        payable(owner()).transfer(_amount);
    }

    // --- View Functions ---

    // Get current collateral ratio for a user
    function getUserCollateralRatio(address _user) public view returns (uint256) {
        uint256 collateral = userCollateral[_user];
        uint256 debt = userDebt[_user];
        if (debt == 0) return type(uint256).max; // Infinite ratio if no debt
        return collateral.mul(100).div(debt);
    }
}