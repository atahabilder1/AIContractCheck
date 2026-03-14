// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VickreyAuction {
    address public seller;
    uint256 public biddingEnd;
    uint256 public revealEnd;
    bool public ended;

    struct Bid {
        bytes32 blindedBid;
        uint256 deposit;
    }

    mapping(address => Bid) public bids;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public secondHighestBid;

    event AuctionEnded(address winner, uint256 highestBid);

    modifier onlyBefore(uint256 _time) {
        require(block.timestamp < _time, "Function called too late.");
        _;
    }

    modifier onlyAfter(uint256 _time) {
        require(block.timestamp > _time, "Function called too early.");
        _;
    }

    constructor(uint256 _biddingTime, uint256 _revealTime) {
        seller = msg.sender;
        biddingEnd = block.timestamp + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }

    function generateBlindedBidBytes32(uint256 _value, bool _fake, bytes32 _secret)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_value, _fake, _secret));
    }

    function bid(bytes32 _blindedBid) external payable onlyBefore(biddingEnd) {
        bids[msg.sender] = Bid({
            blindedBid: _blindedBid,
            deposit: msg.value
        });
    }

    function reveal(uint256 _value, bool _fake, bytes32 _secret) external onlyAfter(biddingEnd) onlyBefore(revealEnd) {
        Bid storage bidToCheck = bids[msg.sender];
        require(bidToCheck.blindedBid == keccak256(abi.encodePacked(_value, _fake, _secret)), "Invalid bid reveal.");
        require(bidToCheck.deposit >= _value, "Insufficient deposit.");

        if (!_fake && bidToCheck.deposit >= _value) {
            if (_value > highestBid) {
                secondHighestBid = highestBid;
                highestBid = _value;
                highestBidder = msg.sender;
            } else if (_value > secondHighestBid) {
                secondHighestBid = _value;
            }
        }

        bidToCheck.blindedBid = bytes32(0);
    }

    function auctionEnd() external onlyAfter(revealEnd) {
        require(!ended, "Auction is already ended.");
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
        payable(seller).transfer(secondHighestBid);
    }

    function withdraw() external {
        Bid storage bidToWithdraw = bids[msg.sender];
        require(bidToWithdraw.blindedBid == bytes32(0), "Bid not revealed.");
        uint256 amount = bidToWithdraw.deposit;
        bidToWithdraw.deposit = 0;
        payable(msg.sender).transfer(amount);
    }
}