// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public arbiter;
    address public beneficiary;
    address public depositor;
    bool public released;

    constructor(address _arbiter, address _beneficiary) {
        arbiter = _arbiter;
        beneficiary = _beneficiary;
        depositor = msg.sender;
    }

    function release() public {
        require(msg.sender == arbiter || msg.sender == beneficiary);
        require(!released);
        released = true;
        payable(beneficiary).transfer(address(this).balance);
    }

    function refundDepositor() public {
        require(msg.sender == depositor);
        require(!released);
        released = true;
        payable(depositor).transfer(address(this).balance);
    }
}