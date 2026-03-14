// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleAuction {
    address public auctioneer;
    address public highestBidder;
    uint public highestBid;
    uint public auctionEndTime;

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    constructor(uint _biddingTime) {
        auctioneer = msg.sender;
        auctionEndTime = block.timestamp + _biddingTime;
    }

    function bid() external payable {
        require(block.timestamp <= auctionEndTime, "Auction already ended.");
        require(msg.value > highestBid, "There already is a higher bid.");

        if (highestBid != 0) {
            payable(highestBidder).transfer(highestBid);
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function endAuction() external {
        require(msg.sender == auctioneer, "Only auctioneer can end the auction.");
        require(block.timestamp >= auctionEndTime, "Auction has not ended yet.");
        require(highestBidder != address(0), "No bids were received.");

        emit AuctionEnded(highestBidder, highestBid);
        payable(auctioneer).transfer(highestBid);
    }
}