pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    address public arbiter;
    uint public amount;
    bool public released;

    constructor(address _buyer, address _seller, address _arbiter, uint _amount) public {
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        amount = _amount;
        released = false;
    }

    function release() public {
        require(msg.sender == buyer || msg.sender == seller || msg.sender == arbiter, "Only the buyer, seller, or arbiter can release the funds");
        require(released == false, "Funds have already been released");
        released = true;
    }

    function refund() public {
        require(msg.sender == buyer || msg.sender == seller || msg.sender == arbiter, "Only the buyer, seller, or arbiter can refund the funds");
        require(released == false, "Funds have already been released");
        require(block.timestamp > 10 days, "The escrow period has not yet expired");
        released = true;
    }
}

SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;