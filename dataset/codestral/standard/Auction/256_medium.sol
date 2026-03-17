// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Auction {
    enum AuctionType {English, Dutch}

    struct Bid {
        address bidder;
        uint amount;
    }

    AuctionType public auctionType;
    address payable public beneficiary;
    uint public reservePrice;
    uint public startingPrice;
    uint public bidIncrement;
    uint public duration;
    uint public endTime;

    Bid[] public bids;
    mapping(address => uint) private refunds;

    event BidPlaced(address indexed bidder, uint amount);
    event AuctionEnded();
    event Refund(address indexed bidder, uint amount);

    constructor(AuctionType _auctionType, address payable _beneficiary, uint _reservePrice, uint _startingPrice, uint _bidIncrement, uint _duration) {
        auctionType = _auctionType;
        beneficiary = _beneficiary;
        reservePrice = _reservePrice;
        startingPrice = _startingPrice;
        bidIncrement = _bidIncrement;
        duration = _duration;
        endTime = block.timestamp + duration;
    }

    function placeBid() public payable {
        require(now < endTime, "Auction has ended");
        uint newBidAmount = (auctionType == AuctionType.English) ? msg.value : calculateDutchPrice();
        require(newBidAmount >= startingPrice + bidIncrement * bids.length, "Invalid bid amount");
        if (bids.length > 0) {
            refunds[bids[bids.length - 1].bidder] = bids[bids.length - 1].amount;
        }
        Bid memory newBid = Bid(msg.sender, newBidAmount);
        bids.push(newBid);
        emit BidPlaced(msg.sender, newBidAmount);
    }

    function endAuction() public {
        require(now >= endTime, "Auction has not ended yet");
        if (bids.length == 0) {
            refundAll();
        } else if (bids[bids.length - 1].amount < reservePrice) {
            refundAll();
        } else {
            beneficiary.transfer(bids[bids.length - 1].amount);
            for (uint i = 0; i < bids.length - 1; i++) {
                refunds[bids[i].bidder] = bids[i].amount;
            }
        }
        emit AuctionEnded();
    }

    function withdrawRefund() public {
        require(refunds[msg.sender] > 0, "No refund available");
        uint refundAmount = refunds[msg.sender];
        refunds[msg.sender] = 0;
        payable(msg.sender).transfer(refundAmount);
        emit Refund(msg.sender, refundAmount);
    }

    function calculateDutchPrice() private view returns (uint) {
        uint priceDecrement = startingPrice * duration / bids.length;
        return startingPrice - priceDecrement;
    }

    function refundAll() private {
        for (uint i = 0; i < bids.length; i++) {
            payable(bids[i].bidder).transfer(bids[i].amount);
        }
    }
}