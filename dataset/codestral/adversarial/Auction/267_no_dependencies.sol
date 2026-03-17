// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    struct Bid {
        address bidder;
        uint amount;
    }

    address public beneficiary;
    bool public auctionEnded;
    mapping(uint => Bid) public bids;
    uint public highestBidIndex;

    constructor() {
        beneficiary = msg.sender;
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Only beneficiary can call this function");
        _;
    }

    modifier auctionNotEnded() {
        require(!auctionEnded, "Auction has ended");
        _;
    }

    function bid() public payable auctionNotEnded {
        uint newBidIndex = bids.length++;
        Bid memory bid = Bid(msg.sender, msg.value);
        bids[newBidIndex] = bid;

        if (highestBidIndex == 0 || bid.amount > bids[highestBidIndex].amount) {
            highestBidIndex = newBidIndex;
        }
    }

    function endAuction() public onlyBeneficiary auctionNotEnded {
        auctionEnded = true;
        if (highestBidIndex != 0) {
            Bid memory winningBid = bids[highestBidIndex];
            payable(winningBid.bidder).transfer(address(this).balance);
        } else {
            selfdestruct(payable(msg.sender));
        }
    }
}