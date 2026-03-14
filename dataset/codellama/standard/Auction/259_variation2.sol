// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract VickreyAuction {
    address private owner;
    uint public highestBid;
    uint public secondHighestBid;
    mapping(address => uint) private commitments;

    constructor() public {
        owner = msg.sender;
    }

    function submitCommitment(uint amount) public {
        require(msg.sender != owner, "You cannot bid on your own auction.");
        commitments[msg.sender] = amount;
    }

    function revealBid(uint amount) public {
        require(msg.sender != owner, "You cannot bid on your own auction.");
        require(commitments[msg.sender] >= amount, "You must reveal a higher amount than your commitment.");
        uint revealedBid = amount;
        if (revealedBid > highestBid) {
            highestBid = revealedBid;
            secondHighestBid = highestBid;
        } else if (revealedBid > secondHighestBid) {
            secondHighestBid = revealedBid;
        }
    }

    function finalizeAuction() public {
        require(msg.sender == owner, "Only the owner can finalize the auction.");
        require(block.timestamp > auctionEndTime, "The auction has not yet ended.");
        uint winningBid = highestBid;
        uint winningAmount = secondHighestBid;
        address payable winner = payable(msg.sender);
        winner.transfer(winningBid);
        for (uint i = 0; i < bidders.length; i++) {
            if (bidders[i] != winner) {
                address payable bidder = payable(bidders[i]);
                bidder.transfer(winningAmount);
            }
        }
    }
}