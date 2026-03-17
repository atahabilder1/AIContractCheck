// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Escrow {
    address payable public buyer;
    address payable public seller;
    uint public amount;

    enum State { Created, Paid, Released }
    State public state;

    constructor() {
        state = State.Created;
    }

    function deposit(uint _amount) external {
        require(state == State.Created);
        buyer = msg.sender;
        amount = _amount;
        state = State.Paid;
    }

    function release() external {
        require(msg.sender == seller);
        require(state == State.Paid);
        seller.transfer(amount);
        state = State.Released;
    }

    function refund() external {
        require(msg.sender == buyer);
        require(state != State.Released);
        buyer.transfer(amount);
        state = State.Created;
    }
}