// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public owner;
    uint public highestBid;
    address public highestBidder;
    bool public ended;

    event BidSubmitted(address bidder, uint amount);

    constructor() public {
        owner = msg.sender;
        highestBid = 0;
        highestBidder = address(0);
        ended = false;
    }

    function bid() public payable {
        require(msg.value > highestBid, "Bid must be higher than current highest bid");
        require(!ended, "Auction has already ended");

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit BidSubmitted(msg.sender, msg.value);
    }

    function endAuction() public {
        require(msg.sender == owner, "Only the owner can end the auction");
        require(!ended, "Auction has already ended");

        ended = true;

        emit AuctionEnded(highestBidder);
    }
}