// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
  address public buyer;
  address public seller;
  uint public amount;

  constructor(address _buyer, address _seller, uint _amount) {
    buyer = _buyer;
    seller = _seller;
    amount = _amount;
  }

  function release() public {
    require(msg.sender == seller, "Only the seller can release the funds");
    payable(buyer).transfer(amount);
  }

  function refund() public {
    require(msg.sender == buyer, "Only the buyer can refund the funds");
    payable(seller).transfer(amount);
  }
}