// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Escrow {
    address public immutable payer;
    address public immutable payee;
    uint8 public s; // 0=active,1=released,2=canceled

    error NotPayer();
    error Inactive();
    error TransferFailed();

    constructor(address payer_, address payee_) payable {
        payer = payer_;
        payee = payee_;
    }

    receive() external payable {
        if (s != 0) revert Inactive();
    }

    function release() external {
        if (msg.sender != payer) revert NotPayer();
        if (s != 0) revert Inactive();
        s = 1;
        uint256 amount = address(this).balance;
        (bool ok, ) = payee.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function cancel() external {
        if (msg.sender != payer) revert NotPayer();
        if (s != 0) revert Inactive();
        s = 2;
        uint256 amount = address(this).balance;
        (bool ok, ) = payer.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}