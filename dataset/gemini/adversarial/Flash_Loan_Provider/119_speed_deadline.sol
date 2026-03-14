// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashLoanProvider is Ownable {
    event LoanCreated(address indexed borrower, address indexed asset, uint256 amount, uint256 fee);
    event LoanRepaid(address indexed borrower, address indexed asset, uint256 amount, uint256 fee);

    mapping(address => uint256) public pendingLoans;
    address public wethAddress; // Example: Address of WETH or any other token

    constructor(address _wethAddress) {
        wethAddress = _wethAddress;
    }

    // Function to initiate a flash loan
    // The borrower must implement the IFlashLoanReceiver interface
    function requestFlashLoan(
        address _borrower,
        address _asset,
        uint256 _amount,
        bytes calldata _data
    ) external onlyOwner {
        require(_borrower != address(0), "FlashLoanProvider: Invalid borrower address");
        require(_asset != address(0), "FlashLoanProvider: Invalid asset address");
        require(_amount > 0, "FlashLoanProvider: Invalid amount");

        IERC20 assetToken = IERC20(_asset);
        uint256 balanceBefore = assetToken.balanceOf(address(this));

        // Transfer assets from the provider to the borrower
        assetToken.transfer(_borrower, _amount);

        // Call the borrower's callback function
        // The borrower will execute their logic and must repay the loan + fee
        IFlashLoanReceiver(_borrower).executeOperation(
            _asset,
            _amount,
            _data
        );

        // After execution, check if the loan has been repaid
        uint256 balanceAfter = assetToken.balanceOf(address(this));
        uint256 repaidAmount = balanceAfter - balanceBefore;

        // For simplicity, we assume the fee is implicitly handled by the borrower
        // In a real scenario, you'd have a specific fee mechanism.
        // For this demo, we'll just check if at least the principal is returned.
        require(repaidAmount >= _amount, "FlashLoanProvider: Loan not repaid");

        // You could calculate and store fees here if implemented
        // uint256 fee = repaidAmount - _amount;
        // emit LoanRepaid(_borrower, _asset, _amount, fee);

        emit LoanRepaid(_borrower, _asset, _amount, 0); // Fee is 0 for this demo
    }

    // Fallback function to receive Ether if needed (e.g., for WETH unwrapping if not using a direct WETH contract)
    receive() external payable {}

    // Function to deposit assets into the provider for lending
    function depositAsset(address _asset, uint256 _amount) external onlyOwner {
        IERC20 assetToken = IERC20(_asset);
        assetToken.transferFrom(msg.sender, address(this), _amount);
    }

    // Function to withdraw assets from the provider (owner only)
    function withdrawAsset(address _asset, uint256 _amount) external onlyOwner {
        IERC20 assetToken = IERC20(_asset);
        assetToken.transfer(owner(), _amount);
    }

    // Function to update the WETH address
    function setWethAddress(address _wethAddress) external onlyOwner {
        wethAddress = _wethAddress;
    }
}

interface IFlashLoanReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}