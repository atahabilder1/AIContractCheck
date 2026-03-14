// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleAuction {
    address payable public owner;
    uint public auctionEndTime;
    address payable public highestBidder;
    uint public highestBid;
    bool public ended;

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    modifier onlyBeforeAuctionEnd() {
        require(block.timestamp < auctionEndTime, "Auction has already ended.");
        _;
    }

    modifier onlyAfterAuctionEnd() {
        require(block.timestamp >= auctionEndTime, "Auction has not ended yet.");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    constructor(uint _biddingTime) {
        owner = payable(msg.sender);
        auctionEndTime = block.timestamp + _biddingTime;
    }

    function bid() public payable onlyBeforeAuctionEnd {
        require(msg.value > highestBid, "Bid must be higher than the current highest bid.");

        if (highestBidder != address(0)) {
            // Refund previous highest bidder
            payable(highestBidder).transfer(highestBid);
        }

        highestBidder = payable(msg.sender);
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function endAuction() public onlyAfterAuctionEnd {
        require(!ended, "Auction has already ended.");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    function withdrawFunds() public onlyOwner onlyAfterAuctionEnd {
        require(highestBidder == address(0), "Auction has not concluded successfully."); // Ensure there was at least one bid
        owner.transfer(address(this).balance);
    }

    // Fallback function to receive Ether directly if needed, though 'bid' is preferred.
    receive() external payable {
        revert("Use the bid() function to place a bid.");
    }
}