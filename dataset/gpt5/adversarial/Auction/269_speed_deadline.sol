// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Auction {
    address payable public seller;
    uint256 public startTime;
    uint256 public endTime;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public pendingReturns;
    bool public ended;

    string public item;

    event HighestBidIncreased(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event BidWithdrawn(address indexed bidder, uint256 amount);

    constructor(uint256 biddingTime, string memory itemName) {
        require(biddingTime > 0, "Duration must be > 0");
        seller = payable(msg.sender);
        startTime = block.timestamp;
        endTime = startTime + biddingTime;
        item = itemName;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Not seller");
        _;
    }

    function bid() external payable {
        require(block.timestamp >= startTime, "Auction not started");
        require(block.timestamp < endTime, "Auction ended");
        require(msg.sender != seller, "Seller cannot bid");
        require(msg.value > highestBid, "Bid not high enough");

        if (highestBidder != address(0)) {
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
            pendingReturns[msg.sender] = amount;
            return false;
        }

        emit BidWithdrawn(msg.sender, amount);
        return true;
    }

    function endAuction() external {
        require(!ended, "Auction already ended");
        require(block.timestamp >= endTime, "Auction not yet ended");

        ended = true;

        emit AuctionEnded(highestBidder, highestBid);

        if (highestBid > 0) {
            (bool success, ) = seller.call{value: highestBid}("");
            require(success, "Payout failed");
        }
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }

    receive() external payable {
        revert("Use bid()");
    }

    fallback() external payable {
        revert("Use bid()");
    }
}