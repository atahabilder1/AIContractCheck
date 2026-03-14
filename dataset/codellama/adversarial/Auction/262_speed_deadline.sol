// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    // Define variables
    address private owner;
    uint public highestBid;
    address public highestBidder;
    uint public bidEndTime;

    // Constructor
    constructor(uint _bidEndTime) public {
        owner = msg.sender;
        highestBid = 0;
        highestBidder = address(0);
        bidEndTime = _bidEndTime;
    }

    // Modifiers
    modifier onlyBefore(uint _time) {
        require(now < _time, "Bidding has already ended");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Bid function
    function bid(uint _amount) public onlyBefore(bidEndTime) {
        require(_amount > highestBid, "Bid must be higher than the current highest bid");
        highestBid = _amount;
        highestBidder = msg.sender;
    }

    // End auction function
    function endAuction() public onlyOwner {
        require(now >= bidEndTime, "Auction has not ended yet");
        owner.transfer(address(this).balance);
    }
}