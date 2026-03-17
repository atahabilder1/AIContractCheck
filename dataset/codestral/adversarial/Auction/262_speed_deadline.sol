// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public highestBidder;
    uint public highestBid;

    function bid() public payable {
        require(msg.value > highestBid, "There is already a higher bid");
        if (highestBid != 0) {
            highestBidder.transfer(highestBid);
        }
        highestBid = msg.value;
        highestBidder = msg.sender;
    }

    function withdraw() public {
        require(msg.sender == highestBidder, "Only the highest bidder can withdraw");
        msg.sender.transfer(highestBid);
        highestBid = 0;
    }
}