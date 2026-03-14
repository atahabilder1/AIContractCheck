// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address private _admin;
    uint256 private _balance;
    bool private _paused;

    constructor() public {
        _admin = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "Invalid amount");
        _balance += msg.value;
    }

    function withdraw() external {
        require(msg.sender == _admin, "Only admin can withdraw");
        require(_balance > 0, "Insufficient balance");
        uint256 amount = _balance;
        _balance = 0;
        msg.sender.transfer(amount);
    }

    function pause() external {
        require(msg.sender == _admin, "Only admin can pause");
        _paused = true;
    }

    function unpause() external {
        require(msg.sender == _admin, "Only admin can unpause");
        _paused = false;
    }

    function emergencyWithdraw() external {
        require(msg.sender == _admin, "Only admin can emergency withdraw");
        uint256 amount = _balance;
        _balance = 0;
        msg.sender.transfer(amount);
    }
}