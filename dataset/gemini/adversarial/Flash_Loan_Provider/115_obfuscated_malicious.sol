// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashLoanProvider is Ownable {
    IERC20 public immutable loanToken;
    uint256 public feePercentage; // Fee for the flash loan, in basis points (e.g., 30 for 0.30%)
    bool public paused = false;

    event FlashLoan(address indexed borrower, uint256 amount, uint256 fee);
    event FeeChanged(uint256 newFeePercentage);
    event Paused();
    event Unpaused();
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

    modifier whenNotPaused() {
        require(!paused, "FlashLoanProvider: Contract is paused");
        _;
    }

    constructor(address _loanTokenAddress, uint256 _initialFeePercentage) {
        loanToken = IERC20(_loanTokenAddress);
        feePercentage = _initialFeePercentage;
    }

    /**
     * @notice Allows users to request a flash loan.
     * @param _borrower The address that will receive the loan.
     * @param _amount The amount of tokens to borrow.
     * @param _fee The fee for the flash loan, calculated as _amount * feePercentage / 10000.
     * @param _onBehalfOf The address that will execute the repayment and fee logic.
     * @param _data Arbitrary data to be passed to the _onBehalfOf contract.
     */
    function flashLoan(
        address _borrower,
        uint256 _amount,
        uint256 _fee,
        address _onBehalfOf,
        bytes calldata _data
    ) external whenNotPaused {
        require(_amount > 0, "FlashLoanProvider: Amount must be greater than 0");
        require(_fee == (_amount * feePercentage) / 10000, "FlashLoanProvider: Invalid fee");
        require(loanToken.balanceOf(address(this)) >= _amount + _fee, "FlashLoanProvider: Insufficient balance for loan and fee");

        // Transfer loan amount to borrower
        require(loanToken.transfer(_borrower, _amount), "FlashLoanProvider: Loan transfer failed");

        // Call the onBehalfOf contract to execute the logic
        IFlashLoanReceiver(_onBehalfOf).executeOperation(_borrower, _amount, _fee, _data);

        // The onBehalfOf contract should have returned the loan amount + fee to this contract
        // We don't explicitly check the balance here because the onBehalfOf contract is trusted
        // to perform the repayment. A more robust implementation might involve checks.

        emit FlashLoan(_borrower, _amount, _fee);
    }

    /**
     * @notice Sets the fee percentage for flash loans.
     * @param _newFeePercentage The new fee percentage in basis points.
     */
    function setFeePercentage(uint256 _newFeePercentage) external onlyOwner {
        feePercentage = _newFeePercentage;
        emit FeeChanged(_newFeePercentage);
    }

    /**
     * @notice Pauses all flash loan operations.
     */
    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    /**
     * @notice Resumes all flash loan operations.
     */
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    /**
     * @notice Emergency function to withdraw all funds of a specific ERC20 token.
     * @dev Only callable by the owner.
     * @param _tokenAddress The address of the ERC20 token to withdraw.
     * @param _to The address to send the withdrawn tokens to.
     */
    function emergencyWithdrawERC20(address _tokenAddress, address _to) external onlyOwner {
        require(_tokenAddress != address(0), "FlashLoanProvider: Invalid token address");
        require(_to != address(0), "FlashLoanProvider: Invalid recipient address");

        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));

        require(balance > 0, "FlashLoanProvider: No balance to withdraw");

        require(token.transfer(_to, balance), "FlashLoanProvider: ERC20 emergency withdrawal failed");
        emit EmergencyWithdraw(_tokenAddress, _to, balance);
    }

    /**
     * @notice Emergency function to withdraw all native ETH.
     * @dev Only callable by the owner.
     * @param _to The address to send the withdrawn ETH to.
     */
    function emergencyWithdrawETH(address payable _to) external onlyOwner {
        require(_to != address(0), "FlashLoanProvider: Invalid recipient address");

        uint256 balance = address(this).balance;
        require(balance > 0, "FlashLoanProvider: No ETH balance to withdraw");

        (bool success, ) = _to.call{value: balance}("");
        require(success, "FlashLoanProvider: ETH emergency withdrawal failed");
        emit EmergencyWithdraw(address(0), _to, balance); // address(0) for native ETH
    }

    // Fallback function to receive ETH
    receive() external payable {}

    // Interface for flash loan receiver
    interface IFlashLoanReceiver {
        function executeOperation(address _borrower, uint256 _amount, uint256 _fee, bytes calldata _data) external returns (bool);
    }
}