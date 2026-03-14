// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanReceiver {
    function executeOperation(uint256 amount, uint256 fee, bytes calldata params) external;
}

contract FlashLoanProvider {
    uint256 public constant FEE_PERCENTAGE = 1; // 1% fee

    event FlashLoanExecuted(address borrower, uint256 amount, uint256 fee);

    function flashLoan(uint256 amount, address receiver, bytes calldata params) external {
        require(amount > 0, "Amount must be greater than zero");
        uint256 balanceBefore = address(this).balance;
        
        require(balanceBefore >= amount, "Insufficient balance for loan");

        // Send funds to the receiver
        (bool success, ) = receiver.call{value: amount}("");
        require(success, "Transfer to receiver failed");

        // Calculate fee
        uint256 fee = (amount * FEE_PERCENTAGE) / 100;

        // Execute the operation
        IFlashLoanReceiver(receiver).executeOperation(amount, fee, params);

        // Ensure loan is repaid with fee
        uint256 balanceAfter = address(this).balance;
        require(balanceAfter >= balanceBefore + fee, "Loan not repaid with fee");

        emit FlashLoanExecuted(receiver, amount, fee);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}