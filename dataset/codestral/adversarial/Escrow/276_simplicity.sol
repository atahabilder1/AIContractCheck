// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Escrow {
    address payable public buyer;
    address payable public seller;
    uint public amount;

    enum State { Created, Locked, Released }
    State public state;

    constructor() {
        state = State.Created;
    }

    function deposit(uint _amount) public payable {
        require(state == State.Created, "Contract is not in created state");
        buyer = msg.sender;
        amount = _amount;
        state = State.Locked;
    }

    function release() public {
        require(msg.sender == seller, "Only the seller can call this function");
        require(state == State.Locked, "Contract is not in locked state");
        seller.transfer(amount);
        state = State.Released;
    }
}