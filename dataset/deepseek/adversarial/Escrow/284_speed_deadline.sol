// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public arbiter;
    address public beneficiary;
    address public depositor;
    bool public isApproved;

    constructor(address _arbiter, address _beneficiary) {
        arbiter = _arbiter;
        beneficiary = _beneficiary;
        depositor = msg.sender;
    }

    function approveTransfer() public {
        require(msg.sender == arbiter, "Only arbiter can approve the transfer.");
        isApproved = true;
    }

    function releaseFunds() public {
        require(isApproved, "Transfer must be approved first.");
        require(msg.sender == beneficiary, "Only beneficiary can release the funds.");
        payable(beneficiary).transfer(address(this).balance);
    }
}