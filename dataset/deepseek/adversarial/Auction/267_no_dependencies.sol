// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public owner;
    uint256 public auctionEndTime;
    uint256 public highestBid;
    address public highestBidder;
    bool public ended;
    mapping(address => uint256) public bids;

    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < auctionEndTime, "Auction has already ended");
        _;
    }

    constructor(uint256 durationInMinutes) {
        require(durationInMinutes > 0, "Duration must be greater than 0");
        owner = msg.sender;
        auctionEndTime = block.timestamp + durationInMinutes * 1 minutes;
    }

    function placeBid() public payable auctionActive {
        require(msg.value > highestBid, "There already is a higher bid");
        bids[msg.sender] = msg.value;
        highestBid = msg.value;
        highestBidder = msg.sender;
        emit BidPlaced(msg.sender, msg.value);
    }

    function endAuction() public onlyOwner {
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(!ended, "Auction has already been ended");
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }
}