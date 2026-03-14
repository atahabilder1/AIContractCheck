// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnglishAuction {
    address public owner;
    address public highestBidder;
    uint public highestBid;
    uint public endTimestamp;

    event AuctionStarted(uint endTimestamp);
    event BidPlaced(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier auctionRunning() {
        require(block.timestamp < endTimestamp, "Auction ended");
        _;
    }

    constructor(uint _duration) {
        owner = msg.sender;
        endTimestamp = block.timestamp + _duration;
        emit AuctionStarted(endTimestamp);
    }

    function bid() external payable auctionRunning {
        require(msg.value > highestBid, "Bid too low");
        if (highestBidder != address(0)) {
            payable(highestBidder).transfer(highestBid);
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit BidPlaced(msg.sender, msg.value);
    }

    function endAuction() external onlyOwner {
        require(block.timestamp >= endTimestamp, "Auction still running");
        emit AuctionEnded(highestBidder, highestBid);
        payable(owner).transfer(highestBid);
    }
}