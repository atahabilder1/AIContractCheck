// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    enum AuctionType { English, Dutch }

    AuctionType public auctionType;
    uint public reservePrice;
    uint public endTime;
    uint public bidIncrement;
    address payable public highestBidder;
    uint public highestBid;
    bool public auctionEnded;
    mapping(address => uint) public bids;

    event BidPlaced(address indexed bidder, uint amount);
    event AuctionEnded(address indexed winner, uint amount);

    constructor(AuctionType _auctionType, uint _reservePrice, uint _endTime, uint _bidIncrement) {
        auctionType = _auctionType;
        reservePrice = _reservePrice;
        endTime = _endTime;
        bidIncrement = _bidIncrement;
    }

    modifier onlyBeforeEndTime() {
        require(block.timestamp < endTime, "Auction already ended.");
        _;
    }

    modifier onlyAfterEndTime() {
        require(block.timestamp >= endTime, "Auction not yet ended.");
        _;
    }

    function placeBid() public payable onlyBeforeEndTime {
        require(msg.value > 0, "Bid amount must be greater than zero.");

        if (auctionType == AuctionType.English) {
            require(msg.value >= highestBid + bidIncrement, "Bid must be at least the current highest bid plus the bid increment.");
        } else if (auctionType == AuctionType.Dutch) {
            require(msg.value >= reservePrice && msg.value >= highestBid + bidIncrement, "Bid must be at least the reserve price or the current highest bid plus the bid increment.");
        }

        if (highestBid != 0) {
            bids[highestBidder] += highestBid;
        }

        highestBidder = payable(msg.sender);
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    function endAuction() public onlyAfterEndTime {
        require(!auctionEnded, "Auction has already ended.");
        auctionEnded = true;

        if (auctionType == AuctionType.Dutch && highestBid < reservePrice) {
            highestBidder.transfer(highestBid);
        } else {
            highestBidder.transfer(highestBid);
        }

        emit AuctionEnded(highestBidder, highestBid);
    }
}