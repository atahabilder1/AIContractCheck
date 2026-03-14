// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    struct LockedFunds {
        uint256 amount;
        uint256 releaseTime;
    }

    mapping(address => LockedFunds) private lockedFunds;

    event FundsLocked(address indexed sender, uint256 amount, uint256 releaseTime);
    event FundsWithdrawn(address indexed receiver, uint256 amount);

    function lockFunds(uint256 _releaseTime) external payable {
        require(msg.value > 0, "No funds sent");
        require(_releaseTime > block.timestamp, "Release time is in the past");

        LockedFunds storage userFunds = lockedFunds[msg.sender];
        userFunds.amount += msg.value;
        userFunds.releaseTime = _releaseTime;

        emit FundsLocked(msg.sender, msg.value, _releaseTime);
    }

    function withdrawFunds() external {
        LockedFunds storage userFunds = lockedFunds[msg.sender];
        require(block.timestamp >= userFunds.releaseTime, "Funds are still locked");
        require(userFunds.amount > 0, "No funds to withdraw");

        uint256 amountToWithdraw = userFunds.amount;
        userFunds.amount = 0;

        (bool success, ) = msg.sender.call{value: amountToWithdraw}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(msg.sender, amountToWithdraw);
    }

    function getLockedFunds(address _account) external view returns (uint256 amount, uint256 releaseTime) {
        LockedFunds storage userFunds = lockedFunds[_account];
        return (userFunds.amount, userFunds.releaseTime);
    }
}