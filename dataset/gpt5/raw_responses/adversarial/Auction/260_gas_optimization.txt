// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Auction {
    error AuctionEnded();
    error AuctionNotEnded();
    error BidTooLow();
    error NoRefund();
    error TransferFailed();

    address payable public immutable beneficiary;
    uint256 public immutable endTime;

    address payable public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public refunds;
    bool public ended;

    constructor(uint256 duration, address payable _beneficiary) {
        beneficiary = _beneficiary;
        unchecked {
            endTime = block.timestamp + duration;
        }
    }

    function bid() external payable {
        if (block.timestamp >= endTime) revert AuctionEnded();

        uint256 hb = highestBid;
        if (msg.value <= hb) revert BidTooLow();

        address payable prev = highestBidder;
        if (prev != address(0)) {
            unchecked {
                refunds[prev] += hb;
            }
        }

        highestBid = msg.value;
        highestBidder = payable(msg.sender);
    }

    function withdraw() external {
        uint256 amount = refunds[msg.sender];
        if (amount == 0) revert NoRefund();

        refunds[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) {
            refunds[msg.sender] = amount;
            revert TransferFailed();
        }
    }

    function end() external {
        if (block.timestamp < endTime) revert AuctionNotEnded();
        if (ended) revert AuctionEnded();

        ended = true;
        uint256 amount = highestBid;
        highestBid = 0;

        (bool ok, ) = beneficiary.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}