// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public payer;
    address public beneficiary;
    uint public amount;
    bool public locked = false;

    constructor(address _beneficiary) {
        beneficiary = _beneficiary;
    }

    function deposit() external payable {
        require(!locked, "Contract is locked");
        payer = msg.sender;
        amount = msg.value;
        locked = true;
    }

    function releaseFunds() external {
        require(msg.sender == beneficiary && locked, "Not authorized or contract is not locked");
        (bool success, ) = payable(payer).call{value: amount}("");
        require(success, "Transfer failed.");
        payer = address(0);
        amount = 0;
        locked = false;
    }
}