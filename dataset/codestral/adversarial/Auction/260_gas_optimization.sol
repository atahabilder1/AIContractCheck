// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Auction {
    struct Bid {
        address bidder;
        uint amount;
    }

    Bid private highestBid;
    uint public auctionEndTime;
    bool private ended;

    event HighestBidIncreased(address indexed bidder, uint amount);
    event AuctionEnded(address indexed winner, uint amount);

    constructor(uint _auctionEndTime) {
        auctionEndTime = block.timestamp + _auctionEndTime;
    }

    function bid() public payable {
        require(msg.value > highestBid.amount, "Bid must be higher than current highest bid");
        require(!ended, "Auction has already ended");
        require(block.timestamp < auctionEndTime, "Auction has ended");

        if (highestBid.bidder != address(0)) {
            payable(highestBid.bidder).transfer(highestBid.amount);
        }

        highestBid.bidder = msg.sender;
        highestBid.amount = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function endAuction() public {
        require(block.timestamp >= auctionEndTime, "Auction has not ended yet");
        require(!ended, "Auction has already ended");

        ended = true;
        emit AuctionEnded(highestBid.bidder, highestBid.amount);
    }
}