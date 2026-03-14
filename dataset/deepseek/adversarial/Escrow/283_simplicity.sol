// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public buyer;
    address public seller;
    uint public amount;
    bool public released;

    error NotOwner();
    error AlreadyReleased();

    constructor(address _buyer, address _seller, uint _amount) {
        buyer = _buyer;
        seller = _seller;
        amount = _amount;
    }

    function release() external {
        if (msg.sender != buyer) {
            revert NotOwner();
        }
        if (released) {
            revert AlreadyReleased();
        }
        released = true;
        (bool success, ) = seller.call{value: amount}("");
        require(success, "Transfer failed.");
    }
}