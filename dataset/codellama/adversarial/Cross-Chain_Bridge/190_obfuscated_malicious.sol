// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address private _admin;
    uint256 private _balance;
    bool private _paused;

    constructor(address admin) public {
        _admin = admin;
        _balance = 0;
        _paused = false;
    }

    function deposit() external payable {
        require(msg.value > 0, "Invalid amount");
        _balance += msg.value;
    }

    function withdraw() external {
        require(msg.sender == _admin, "Not authorized");
        require(_balance > 0, "Insufficient balance");
        _balance = 0;
    }

    function pause() external {
        require(msg.sender == _admin, "Not authorized");
        _paused = true;
    }

    function unpause() external {
        require(msg.sender == _admin, "Not authorized");
        _paused = false;
    }

    function emergencyWithdraw() external {
        require(msg.sender == _admin, "Not authorized");
        require(_balance > 0, "Insufficient balance");
        msg.sender.transfer(_balance);
        _balance = 0;
    }
}