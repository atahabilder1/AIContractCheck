// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Auction {
    address public immutable seller;
    uint96 public endTime;
    address public highestBidder;
    uint256 public highestBid;
    bool public ended;

    mapping(address => uint256) public pendingReturns;

    event HighestBidIncreased(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    error AuctionAlreadyEnded();
    error BidTooLow();
    error AuctionNotYetEnded();
    error AuctionEndAlreadyCalled();
    error TransferFailed();
    error NotSeller();
    error NothingToWithdraw();

    constructor(uint96 _duration) {
        seller = msg.sender;
        endTime = uint96(block.timestamp) + _duration;
    }

    function bid() external payable {
        if (block.timestamp >= endTime) revert AuctionAlreadyEnded();
        if (msg.value <= highestBid) revert BidTooLow();

        uint256 _highestBid = highestBid;
        address _highestBidder = highestBidder;

        if (_highestBid != 0) {
            unchecked {
                pendingReturns[_highestBidder] += _highestBid;
            }
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        pendingReturns[msg.sender] = 0;

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function endAuction() external {
        if (block.timestamp < endTime) revert AuctionNotYetEnded();
        if (ended) revert AuctionEndAlreadyCalled();

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        uint256 _highestBid = highestBid;
        if (_highestBid != 0) {
            (bool ok,) = seller.call{value: _highestBid}("");
            if (!ok) revert TransferFailed();
        }
    }
}