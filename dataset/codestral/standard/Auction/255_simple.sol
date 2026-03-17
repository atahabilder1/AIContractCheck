// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnglishAuction {
    address payable public highestBidder;
    uint public highestBid;
    uint public auctionEndTime;

    constructor(uint _auctionEndTime) {
        auctionEndTime = _auctionEndTime;
    }

    function bid() external payable {
        require(msg.value > highestBid, "Your bid must be higher than the current highest bid.");
        require(now < auctionEndTime, "The auction has ended.");

        if (highestBidder != address(0)) {
            highestBidder.transfer(highestBid);
        }

        highestBid = msg.value;
        highestBidder = payable(msg.sender);
    }

    function withdraw() external {
        require(now >= auctionEndTime, "The auction has not ended yet.");
        require(highestBidder == msg.sender, "Only the highest bidder can withdraw their funds.");

        payable(msg.sender).transfer(highestBid);
    }
}