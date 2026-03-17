// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashLoan {
    function executeOperation(address token, uint amount, bytes calldata data) external returns (bool);
}

contract FlashLoanProvider {
    mapping(address => uint) private balances;

    event LoanRequested(address receiver, address token, uint amount, bytes data);
    event LoanRepaid(address receiver, address token, uint amount, uint fee);

    function deposit(IERC20 token) external {
        require(_msgSender() == msg.sender, "Only the sender can call this function");
        uint amount = token.balanceOf(msg.sender);
        balances[token] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function flashLoan(IERC20 token, uint amount, IFlashLoan receiver) external {
        require(balances[address(token)] >= amount, "Not enough balance");
        balances[address(token)] -= amount;
        emit LoanRequested(address(receiver), address(token), amount, "");

        bool success = receiver.executeOperation(address(token), amount, "");

        if (!success) {
            revert("Operation failed");
        }

        uint fee = calculateFee(amount);
        balances[address(token)] += amount + fee;
        emit LoanRepaid(msg.sender, address(token), amount, fee);
    }

    function calculateFee(uint amount) private pure returns (uint) {
        return amount * 5 / 100; // 5% fee for example
    }
}