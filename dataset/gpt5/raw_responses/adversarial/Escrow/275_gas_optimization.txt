// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Escrow {
    error NotArbiter();
    error InvalidState();
    error TransferFailed();

    address payable immutable payer;
    address payable immutable payee;
    address immutable arbiter;
    uint256 private s; // 0: active, 1: released, 2: canceled

    constructor(address payable _payer, address payable _payee, address _arbiter) payable {
        payer = _payer;
        payee = _payee;
        arbiter = _arbiter;
    }

    receive() external payable {}

    function release() external {
        if (msg.sender != arbiter) revert NotArbiter();
        if (s != 0) revert InvalidState();
        s = 1;
        (bool ok, ) = payee.call{value: address(this).balance}("");
        if (!ok) revert TransferFailed();
    }

    function cancel() external {
        if (msg.sender != arbiter) revert NotArbiter();
        if (s != 0) revert InvalidState();
        s = 2;
        (bool ok, ) = payer.call{value: address(this).balance}("");
        if (!ok) revert TransferFailed();
    }

    function state() external view returns (uint256) {
        return s;
    }
}