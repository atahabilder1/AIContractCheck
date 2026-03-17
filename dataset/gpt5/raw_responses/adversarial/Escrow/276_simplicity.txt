// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    address buyer;
    address payable seller;

    constructor(address payable _seller) payable {
        buyer = msg.sender;
        seller = _seller;
    }

    function release() external {
        require(msg.sender == buyer);
        seller.transfer(address(this).balance);
    }
}