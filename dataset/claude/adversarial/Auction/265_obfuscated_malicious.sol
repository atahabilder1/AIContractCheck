// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public admin;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public auctionEndTime;
    bool public ended;
    bool public paused;

    mapping(address => uint256) public pendingReturns;

    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event Paused(address admin);
    event Unpaused(address admin);
    event EmergencyWithdraw(address admin, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(uint256 _biddingTime) {
        admin = msg.sender;
        auctionEndTime = block.timestamp + _biddingTime;
    }

    function bid() external payable whenNotPaused {
        require(block.timestamp < auctionEndTime, "Auction ended");
        require(msg.value > highestBid, "Bid not high enough");

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function endAuction() external whenNotPaused {
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(!ended, "Already ended");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        (bool success, ) = payable(admin).call{value: highestBid}("");
        require(success, "Transfer failed");
    }

    function pause() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        paused = true;
        ended = true;

        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "Transfer failed");
        emit EmergencyWithdraw(msg.sender, balance);
    }
}