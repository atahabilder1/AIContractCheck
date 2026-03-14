// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public owner;
    uint public highestBid;
    address public highestBidder;
    mapping(address => uint) public bids;

    constructor() public {
        owner = msg.sender;
    }

    function bid(uint amount) public {
        require(amount > highestBid, "Bid must be higher than the current highest bid");
        bids[msg.sender] = amount;
        highestBid = amount;
        highestBidder = msg.sender;
    }

    function endAuction() public {
        require(msg.sender == owner, "Only the owner can end the auction");
        uint winner = highestBidder;
        uint amount = highestBid;
        delete bids[winner];
        delete highestBid;
        delete highestBidder;
        winner.transfer(amount);
    }
}