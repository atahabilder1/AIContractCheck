// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    address public lenderAddress;
    uint24 public feePercentage = 10; // 1%

    constructor(address _lenderAddress) {
        require(_lenderAddress != address(0), "Invalid Lender Address");
        lenderAddress = _lenderAddress;
    }

    function flashLoan(uint256 amount, bytes calldata data) external returns (bool) {
        uint256 feeAmount = (amount * feePercentage) / 100;
        require(msg.sender.call{value: amount}(""), "Flash loan failed");

        // Execute user-provided callback function
        bool success = false;
        assembly {
            success := call(sub(gas(), 5000), data, 0, add(data, mload(data)), amount, 0, 0)
        }
        require(success, "Callback failed");

        // Transfer fee to the lender
        payable(lenderAddress).transfer(feeAmount);
        return true;
    }
}