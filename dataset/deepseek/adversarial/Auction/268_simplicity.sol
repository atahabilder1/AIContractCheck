// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public owner;
    uint256 public endTime;
    bool public ended;
    uint256 public highestBid;
    address public highestBidder;
    mapping(address => uint256) public bids;

    event BidPlaced(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAfterEnd() {
        require(block.timestamp >= endTime, "Auction not yet ended");
        _;
    }

    constructor(uint256 durationInMinutes) {
        owner = msg.sender;
        endTime = block.timestamp + durationInMinutes * 1 minutes;
    }

    function placeBid() public payable {
        require(block.timestamp < endTime, "Auction already ended");
        require(msg.value > highestBid, "There already is a higher bid");

        bids[msg.sender] = msg.value;
        highestBid = msg.value;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, msg.value);
    }

    function endAuction() public onlyOwner onlyAfterEnd {
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }
}