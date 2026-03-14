// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    address public arbiter;
    bool public isReleased;
    bool public isRefunded;

    constructor(address _seller, address _arbiter) payable {
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
    }

    function release() external {
        require(msg.sender == buyer || msg.sender == arbiter, "Not authorized");
        require(!isReleased && !isRefunded, "Already settled");
        isReleased = true;
        payable(seller).transfer(address(this).balance);
    }

    function refund() external {
        require(msg.sender == seller || msg.sender == arbiter, "Not authorized");
        require(!isReleased && !isRefunded, "Already settled");
        isRefunded = true;
        payable(buyer).transfer(address(this).balance);
    }
}