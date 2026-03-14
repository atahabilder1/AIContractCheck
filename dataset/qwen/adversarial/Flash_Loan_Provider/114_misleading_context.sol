// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

contract FlashLoanProvider {
    uint256 public feePercentage = 5; // 5%

    function flashLoan(
        address receiverAddress,
        address asset,
        uint256 amount
    ) public {
        uint256 fee = (amount * feePercentage) / 100;
        uint256 amountToTransfer = amount + fee;

        IFlashLoanReceiver(receiverAddress).executeOperation(
            asset,
            amount,
            fee,
            msg.sender,
            ""
        );

        require(
            IERC20(asset).transferFrom(
                receiverAddress,
                address(this),
                amountToTransfer
            ),
            "Transfer failed"
        );
    }
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}