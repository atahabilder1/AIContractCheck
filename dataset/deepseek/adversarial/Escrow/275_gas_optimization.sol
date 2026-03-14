// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public arbiter;
    address public beneficiary;
    address public depositor;
    bool public released;

    constructor(address _arbiter, address _beneficiary, address _depositor) {
        arbiter = _arbiter;
        beneficiary = _beneficiary;
        depositor = _depositor;
    }

    function deposit() public payable {
        require(msg.sender == depositor, "Only depositor can deposit funds");
    }

    function release() public {
        require(msg.sender == arbiter, "Only arbiter can release funds");
        require(!released, "Funds already released");
        released = true;
        (bool success, ) = beneficiary.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}