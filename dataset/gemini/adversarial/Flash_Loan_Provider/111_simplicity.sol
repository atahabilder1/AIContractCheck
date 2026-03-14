// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {

    function flashLoan(address _borrower, address _token, uint256 _amount, bytes calldata _data) external {
        require(_token != address(0), "FlashLoanProvider: Invalid token address");
        require(_borrower != address(0), "FlashLoanProvider: Invalid borrower address");

        // Transfer tokens to the borrower
        IERC20(_token).transfer(_borrower, _amount);

        // Call the borrower's callback function
        IFlashLoanReceiver(_borrower).executeFlashLoan(_token, _amount, _data);

        // Ensure the loan is repaid (this requires the borrower to send back the amount + fee)
        // In a real-world scenario, you'd track the loan and enforce repayment or liquidation.
        // For simplicity, we assume the borrower fulfills their obligation.
    }
}

interface IFlashLoanReceiver {
    function executeFlashLoan(address _token, uint256 _amount, bytes calldata _data) external;
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}