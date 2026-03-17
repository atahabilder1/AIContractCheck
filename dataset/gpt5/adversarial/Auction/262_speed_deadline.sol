// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Auction {
    address payable public beneficiary;
    uint256 public auctionEndTime;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public pendingReturns;

    bool public ended;

    event HighestBidIncreased(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    constructor(uint256 biddingTime, address payable beneficiaryAddress) {
        require(biddingTime > 0, "Invalid bidding time");
        require(beneficiaryAddress != address(0), "Invalid beneficiary");
        beneficiary = beneficiaryAddress;
        auctionEndTime = block.timestamp + biddingTime;
    }

    function bid() external payable {
        require(block.timestamp < auctionEndTime, "Auction already ended");
        require(msg.value > highestBid, "Bid not high enough");

        if (highestBid != 0) {
            // Refund the previously highest bidder via withdraw pattern
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function withdraw() external returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            // Restore the amount if transfer failed
            pendingReturns[msg.sender] = amount;
            return false;
        }
        return true;
    }

    function endAuction() external {
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(!ended, "endAuction already called");
        ended = true;

        emit AuctionEnded(highestBidder, highestBid);

        (bool success, ) = beneficiary.call{value: highestBid}("");
        require(success, "Payout failed");
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= auctionEndTime) return 0;
        return auctionEndTime - block.timestamp;
    }

    receive() external payable {
        revert("Use bid()");
    }

    fallback() external payable {
        revert("Use bid()");
    }
}