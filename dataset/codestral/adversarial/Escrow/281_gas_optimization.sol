// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract Escrow {
    address payable public initiator;
    address payable public beneficiary;
    uint256 public amount;
    bool public isLocked = true;

    constructor(address payable _beneficiary, uint256 _amount) {
        initiator = msg.sender;
        beneficiary = _beneficiary;
        amount = _amount;
    }

    modifier onlyInitiator() {
        require(msg.sender == initiator, "Only initiator can call this function");
        _;
    }

    function deposit() public payable onlyInitiator {
        require(isLocked, "Escrow is not locked");
        require(msg.value == amount, "Incorrect amount sent");
    }

    function withdraw() public onlyInitiator {
        require(!isLocked, "Escrow is still locked");
        beneficiary.transfer(amount);
        selfdestruct(payable(initiator));
    }

    function releaseFunds() public {
        require(msg.sender == beneficiary, "Only beneficiary can call this function");
        isLocked = false;
    }
}