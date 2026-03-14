// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EnglishAuction {
    address public seller;
    string public item;
    uint256 public endTime;
    address public highestBidder;
    uint256 public highestBid;
    bool public ended;

    mapping(address => uint256) public pendingReturns;

    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    modifier onlySeller() {
        require(msg.sender == seller, "Not seller");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < endTime, "Auction ended");
        require(!ended, "Auction finalized");
        _;
    }

    constructor(string memory _item, uint256 _durationSeconds) {
        seller = msg.sender;
        item = _item;
        endTime = block.timestamp + _durationSeconds;
    }

    function bid() external payable auctionActive {
        require(msg.value > highestBid, "Bid too low");

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function endAuction() external onlySeller {
        require(block.timestamp >= endTime, "Auction not yet ended");
        require(!ended, "Already finalized");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        if (highestBid > 0) {
            (bool success, ) = payable(seller).call{value: highestBid}("");
            require(success, "Transfer failed");
        }
    }
}