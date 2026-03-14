// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    address public arbiter;
    bool public isDisputed;
    uint256 public amount;

    enum EscrowState { Created, Released, Disputed, Closed }
    EscrowState public state;

    event EscrowCreated(address buyer, address seller, uint256 amount);
    event EscrowReleased(address buyer, address seller, uint256 amount);
    event EscrowDisputed(address arbiter, address buyer, address seller, uint256 amount);
    event EscrowClosed(address buyer, address seller, uint256 amount);

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter can call this function");
        _;
    }

    modifier notDisputed() {
        require(!isDisputed, "Escrow is disputed");
        _;
    }

    constructor(address _buyer, address _seller, uint256 _amount, address _arbiter) {
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        amount = _amount;
        state = EscrowState.Created;
        emit EscrowCreated(buyer, seller, amount);
    }

    function releaseFunds() external onlyArbiter notDisputed {
        state = EscrowState.Released;
        (bool success, ) = seller.call{value: amount}("");
        require(success, "Transfer failed");
        emit EscrowReleased(buyer, seller, amount);
    }

    function dispute() external onlyArbiter {
        isDisputed = true;
        state = EscrowState.Disputed;
        emit EscrowDisputed(arbiter, buyer, seller, amount);
    }

    function resolveDispute() external onlyArbiter {
        isDisputed = false;
        state = EscrowState.Closed;
        (bool success, ) = buyer.call{value: amount}("");
        require(success, "Transfer failed");
        emit EscrowClosed(buyer, seller, amount);
    }
}