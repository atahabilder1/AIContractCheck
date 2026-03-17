// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    address payable public payer;
    address payable public payee;
    address public arbiter;
    uint256 public amount;
    bool public funded;
    bool public closed;

    bool private locked;

    event Deposited(address indexed from, uint256 amount);
    event Released(address indexed to, uint256 amount);
    event Refunded(address indexed to, uint256 amount);

    modifier onlyPayer() {
        require(msg.sender == payer, "Not payer");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Not arbiter");
        _;
    }

    modifier notClosed() {
        require(!closed, "Escrow closed");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address payable _payer, address payable _payee, address _arbiter, uint256 _amount) {
        require(_payer != address(0) && _payee != address(0) && _arbiter != address(0), "Zero address");
        require(_amount > 0, "Amount zero");
        require(_payer != _payee, "Payer=Payee");
        payer = _payer;
        payee = _payee;
        arbiter = _arbiter;
        amount = _amount;
    }

    function deposit() external payable onlyPayer notClosed {
        require(!funded, "Already funded");
        require(msg.value == amount, "Incorrect amount");
        funded = true;
        emit Deposited(msg.sender, msg.value);
    }

    function release() external onlyArbiter notClosed nonReentrant {
        require(funded, "Not funded");
        closed = true;
        uint256 bal = address(this).balance;
        (bool ok, ) = payee.call{value: bal}("");
        require(ok, "Transfer failed");
        emit Released(payee, bal);
    }

    function refund() external onlyArbiter notClosed nonReentrant {
        require(funded, "Not funded");
        closed = true;
        uint256 bal = address(this).balance;
        (bool ok, ) = payer.call{value: bal}("");
        require(ok, "Transfer failed");
        emit Refunded(payer, bal);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }

    fallback() external payable {
        revert("Invalid call");
    }
}