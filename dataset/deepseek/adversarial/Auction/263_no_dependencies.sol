// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address payable public seller;
    bool public ended;
    uint public endTime;
    mapping(address => uint) public bids;
    uint public highestBid;
    address public highestBidder;

    event BidPlaced(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    modifier auctionNotEnded() {
        require(!ended, "Auction already ended");
        _;
    }

    modifier auctionEnded() {
        require(ended, "Auction not yet ended");
        _;
    }

    constructor(uint _durationInSeconds) {
        seller = payable(msg.sender);
        endTime = block.timestamp + _durationInSeconds;
    }

    function placeBid() public payable auctionNotEnded {
        require(block.timestamp < endTime, "Auction already ended");
        require(msg.value > highestBid, "There already is a higher bid");

        if (highestBid != 0) {
            bids[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, msg.value);
    }

    function endAuction() public onlySeller auctionNotEnded {
        require(block.timestamp >= endTime, "Auction not yet ended");
        ended = true;
        seller.transfer(highestBid);
        emit AuctionEnded(highestBidder, highestBid);
    }
}