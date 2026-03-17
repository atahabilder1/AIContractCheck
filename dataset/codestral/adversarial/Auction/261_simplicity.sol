// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SimpleAuction {
    address public highestBidder;
    uint256 public highestBid;

    function bid() external payable {
        require(msg.value > highestBid, "There is already a higher bid");
        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function withdraw() external {
        require(highestBidder == msg.sender, "Only the highest bidder can withdraw");
        highestBidder.transfer(highestBid);
        highestBidder = address(0);
        highestBid = 0;
    }
}