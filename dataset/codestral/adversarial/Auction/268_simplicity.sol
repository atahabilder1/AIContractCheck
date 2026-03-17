// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MinimalAuction {
    struct Bid {
        address bidder;
        uint amount;
    }

    address public beneficiary;
    bool public auctionEnded;
    Bid public highestBid;

    constructor() {
        beneficiary = payable(msg.sender);
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Only the beneficiary can call this function.");
        _;
    }

    function bid() public payable {
        require(!auctionEnded && msg.value > highestBid.amount, "Invalid bid.");
        if (highestBid.bidder != address(0)) {
            payable(highestBid.bidder).transfer(highestBid.amount);
        }
        highestBid = Bid(msg.sender, msg.value);
    }

    function withdraw() public onlyBeneficiary {
        require(auctionEnded && highestBid.bidder != address(0), "Auction has not ended or there is no bid.");
        payable(beneficiary).transfer(highestBid.amount);
        highestBid = Bid(address(0), 0);
    }

    function endAuction() public onlyBeneficiary {
        auctionEnded = true;
    }
}