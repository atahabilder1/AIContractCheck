// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Auction {
    address public seller;
    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public pendingReturns;
    bool public ended;

    constructor() {
        seller = msg.sender;
    }

    function bid() external payable {
        require(!ended, "Auction ended");
        require(msg.value > highestBid, "Bid not high enough");

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function withdraw() external returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) return false;

        pendingReturns[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) {
            pendingReturns[msg.sender] = amount;
            return false;
        }
        return true;
    }

    function end() external {
        require(!ended, "Auction ended");
        require(msg.sender == seller, "Only seller");

        ended = true;

        uint256 amount = highestBid;
        highestBid = 0;
        (bool ok, ) = payable(seller).call{value: amount}("");
        require(ok, "Payment failed");
    }
}