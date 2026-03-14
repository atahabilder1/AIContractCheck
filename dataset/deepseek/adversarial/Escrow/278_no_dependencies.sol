// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public arbiter;
    address public beneficiary;
    address public depositor;
    bool public released;

    error NotOwner();
    error AlreadyReleased();

    constructor(address _arbiter, address _beneficiary, address _depositor) {
        arbiter = _arbiter;
        beneficiary = _beneficiary;
        depositor = _depositor;
    }

    function release() external {
        if (msg.sender != arbiter) {
            revert NotOwner();
        }
        if (released) {
            revert AlreadyReleased();
        }
        released = true;
        payable(beneficiary).transfer(address(this).balance);
    }

    function deposit() external payable {
        if (msg.sender != depositor) {
            revert NotOwner();
        }
    }
}