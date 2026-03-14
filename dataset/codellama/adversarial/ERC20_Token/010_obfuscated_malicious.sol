// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function adminWithdrawAllFunds() external onlyAdmin {
        require(msg.sender == admin, "Only admin can withdraw all funds");
        uint256 totalSupply = totalSupply();
        uint256 balance = balanceOf(msg.sender);
        require(balance >= totalSupply, "Insufficient balance to withdraw all funds");
        transfer(msg.sender, address(this), totalSupply);
        emit Withdrawal(msg.sender, totalSupply);
    }

    function adminPauseOperations() external onlyAdmin {
        require(msg.sender == admin, "Only admin can pause operations");
        paused = true;
        emit Pause(msg.sender, paused);
    }
}