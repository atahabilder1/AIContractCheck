// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GasOptimizedAuction {
    struct Bid {
        address bidder;
        uint amount;
    }

    Bid public highestBid;
    bool public ended;

    function bid() external payable {
        require(msg.value > highestBid.amount, "Bid not high enough");
        if (highestBid.bidder != address(0)) {
            address previousHighestBidder = highestBid.bidder;
            highestBid.bidder = msg.sender;
            highestBid.amount = msg.value;
            previousHighestBidder.transfer(highestBid.amount);
        } else {
            highestBid.bidder = msg.sender;
            highestBid.amount = msg.value;
        }
    }

    function endAuction() external {
        require(!ended, "Auction has already ended");
        require(highestBid.bidder != address(0), "No bids received");
        ended = true;
    }
}