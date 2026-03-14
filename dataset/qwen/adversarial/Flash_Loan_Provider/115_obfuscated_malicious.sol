// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashLoanProvider is Ownable, Pausable {
    mapping(address => uint256) public balances;

    event LoanMade(address indexed borrower, uint256 amount);
    event FundsWithdrawn(uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        balances[msg.sender] += msg.value;
    }

    function flashLoan(address _receiver, uint256 _amount) external whenNotPaused {
        require(balances[address(this)] >= _amount, "Insufficient funds for loan");
        require(_amount > 0, "Loan amount must be greater than zero");

        balances[address(this)] -= _amount;
        (bool success, ) = _receiver.call{value: _amount}("");
        require(success, "Flash loan failed");

        balances[address(this)] += _amount;
        emit LoanMade(_receiver, _amount);
    }

    function withdrawAllFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed");
        emit FundsWithdrawn(balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}