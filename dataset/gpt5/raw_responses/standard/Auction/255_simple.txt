// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EnglishAuction {
    address public immutable seller;
    string public item;
    uint256 public immutable endTime;
    uint256 public immutable startPrice;

    address public highestBidder;
    uint256 public highestBid;
    bool public ended;

    mapping(address => uint256) public pendingReturns;

    event BidPlaced(address indexed bidder, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    constructor(string memory _item, uint256 _biddingTime, uint256 _startPrice) {
        seller = msg.sender;
        item = _item;
        startPrice = _startPrice;
        endTime = block.timestamp + _biddingTime;
    }

    function bid() external payable {
        require(block.timestamp < endTime, "Auction ended");
        uint256 newBid = msg.value;
        require(newBid >= startPrice, "Bid < start");
        require(newBid > highestBid, "Not higher bid");

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBid = newBid;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, newBid);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        pendingReturns[msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) {
            pendingReturns[msg.sender] = amount;
            revert("Withdraw failed");
        }

        emit Withdrawn(msg.sender, amount);
    }

    function end() external {
        require(block.timestamp >= endTime, "Auction not yet ended");
        require(!ended, "Already ended");
        ended = true;

        uint256 amount = highestBid;
        address winner = highestBidder;

        if (amount > 0) {
            (bool ok, ) = payable(seller).call{value: amount}("");
            require(ok, "Payout failed");
        }

        emit AuctionEnded(winner, amount);
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }

    receive() external payable {
        revert("Use bid()");
    }

    fallback() external payable {
        revert("Use bid()");
    }
}