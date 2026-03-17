// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Auction {
    // Auction parameters
    address payable public beneficiary;
    string public item;
    uint64 public startTime;
    uint64 public endTime;

    // Current state of the auction
    address public highestBidder;
    uint256 public highestBid;
    bool public ended;

    // Track refunds for overbid bidders
    mapping(address => uint256) public pendingReturns;

    // Events
    event AuctionCreated(address indexed seller, string item, uint64 startTime, uint64 endTime);
    event BidPlaced(address indexed bidder, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    constructor(uint64 biddingTimeSeconds, string memory _item) {
        beneficiary = payable(msg.sender);
        item = _item;
        startTime = uint64(block.timestamp);
        endTime = startTime + biddingTimeSeconds;

        emit AuctionCreated(beneficiary, item, startTime, endTime);
    }

    function bid() external payable {
        require(block.timestamp < endTime, "Auction: already ended");
        require(msg.value > highestBid, "Auction: bid not high enough");

        if (highestBid != 0) {
            // Refund the previous highest bid
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    function withdraw() external returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Auction: nothing to withdraw");

        // Effects before interaction
        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            // Revert state if transfer fails
            pendingReturns[msg.sender] = amount;
            return false;
        }

        emit Withdrawn(msg.sender, amount);
        return true;
    }

    function endAuction() external {
        require(!ended, "Auction: already ended");
        require(block.timestamp >= endTime, "Auction: not yet ended");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        // Transfer highest bid to beneficiary
        (bool sent, ) = beneficiary.call{value: highestBid}("");
        require(sent, "Auction: payout failed");
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }

    // Prevent accidental ETH transfers
    receive() external payable {
        revert("Auction: send ETH via bid()");
    }

    fallback() external payable {
        revert("Auction: invalid call");
    }
}