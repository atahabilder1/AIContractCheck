// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract VickreyAuction {
    mapping(address => uint) private commitments;
    mapping(address => uint) private bids;
    address[] private bidders;

    constructor() {}

    function submitCommitment(bytes32 commitmentHash) public {
        commitments[msg.sender] = uint(keccak256(abi.encodePacked(commitmentHash, msg.sender)));
    }

    function revealBid(uint bid, bytes32 secret) public {
        require(commitments[msg.sender] == uint(keccak256(abi.encodePacked(secret, msg.sender))), "Invalid commitment");
        bids[msg.sender] = bid;
        bidders.push(msg.sender);
    }

    function endAuction() public {
        require(bidders.length >= 2, "Not enough bidders");

        uint highestBid = 0;
        uint secondHighestBid = 0;
        address winner;

        for (uint i = 0; i < bidders.length; i++) {
            if (bids[bidders[i]] > highestBid) {
                secondHighestBid = highestBid;
                highestBid = bids[bidders[i]];
                winner = bidders[i];
            } else if (bids[bidders[i]] > secondHighestBid) {
                secondHighestBid = bids[bidders[i]];
            }
        }

        payable(winner).transfer(secondHighestBid);
    }
}