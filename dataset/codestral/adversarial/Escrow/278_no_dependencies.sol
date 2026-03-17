// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address payable public sender;
    address payable public receiver;
    uint public amount;
    bool public isLocked;

    event Locked(address indexed _sender, address indexed _receiver, uint _amount);
    event Released(uint _amount);

    constructor() {
        sender = msg.sender;
        receiver = payable(0x0); // Set to 0 initially
        amount = 0;
        isLocked = false;
    }

    function deposit() public payable {
        require(!isLocked, "Contract is locked");
        require(msg.value > 0, "Deposit amount must be greater than zero");
        sender = msg.sender;
        amount += msg.value;
        emit Locked(sender, receiver, amount);
    }

    function setReceiver(address payable _receiver) public {
        require(!isLocked, "Contract is locked");
        require(_receiver != address(0), "Receiver cannot be zero address");
        receiver = _receiver;
    }

    function release() public {
        require(isLocked, "Contract is not locked");
        require(msg.sender == receiver || msg.sender == sender, "Only sender or receiver can release funds");
        receiver.transfer(amount);
        amount = 0;
        emit Released(amount);
    }
}