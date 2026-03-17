// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Auction {
    address payable public beneficiary;
    uint256 public endTime;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public pendingReturns;
    bool public ended;

    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    constructor(uint256 biddingTime, address payable _beneficiary) {
        beneficiary = _beneficiary;
        endTime = block.timestamp + biddingTime;
    }

    function bid() external payable {
        require(block.timestamp < endTime, "Auction ended");
        require(msg.value > highestBid, "Bid not high enough");

        if (highestBid != 0) {
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
        return true;
    }

    function endAuction() external {
        require(block.timestamp >= endTime, "Not yet ended");
        require(!ended, "Already ended");
        ended = true;

        emit AuctionEnded(highestBidder, highestBid);

        (bool ok, ) = beneficiary.call{value: highestBid}("");
        require(ok, "Payout failed");
    }
}