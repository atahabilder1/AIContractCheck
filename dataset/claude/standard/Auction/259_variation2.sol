// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VickreyAuction {
    address public seller;
    address public nftContract;
    uint256 public tokenId;

    uint256 public biddingEnd;
    uint256 public revealEnd;
    uint256 public minimumBid;

    struct Bid {
        bytes32 commitment;
        uint256 deposit;
        bool revealed;
        uint256 value;
    }

    mapping(address => Bid) public bids;

    address public highestBidder;
    uint256 public highestBid;
    address public secondHighestBidder;
    uint256 public secondHighestBid;

    bool public ended;

    event BidCommitted(address indexed bidder, uint256 deposit);
    event BidRevealed(address indexed bidder, uint256 value);
    event AuctionEnded(address winner, uint256 price);

    modifier onlySeller() {
        require(msg.sender == seller, "Not seller");
        _;
    }

    modifier onlyBefore(uint256 time) {
        require(block.timestamp < time, "Too late");
        _;
    }

    modifier onlyAfter(uint256 time) {
        require(block.timestamp >= time, "Too early");
        _;
    }

    constructor(
        uint256 _biddingDuration,
        uint256 _revealDuration,
        uint256 _minimumBid
    ) {
        seller = msg.sender;
        biddingEnd = block.timestamp + _biddingDuration;
        revealEnd = biddingEnd + _revealDuration;
        minimumBid = _minimumBid;
    }

    function commitBid(bytes32 _commitment) external payable onlyBefore(biddingEnd) {
        require(bids[msg.sender].commitment == bytes32(0), "Already committed");
        require(msg.value > 0, "Deposit required");

        bids[msg.sender] = Bid({
            commitment: _commitment,
            deposit: msg.value,
            revealed: false,
            value: 0
        });

        emit BidCommitted(msg.sender, msg.value);
    }

    function generateCommitment(uint256 _value, bytes32 _nonce) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_value, _nonce));
    }

    function revealBid(uint256 _value, bytes32 _nonce)
        external
        onlyAfter(biddingEnd)
        onlyBefore(revealEnd)
    {
        Bid storage bid = bids[msg.sender];
        require(bid.commitment != bytes32(0), "No commitment");
        require(!bid.revealed, "Already revealed");

        bytes32 computedHash = keccak256(abi.encodePacked(_value, _nonce));
        require(computedHash == bid.commitment, "Invalid reveal");
        require(_value >= minimumBid, "Below minimum bid");
        require(bid.deposit >= _value, "Deposit less than bid");

        bid.revealed = true;
        bid.value = _value;

        if (_value > highestBid) {
            secondHighestBidder = highestBidder;
            secondHighestBid = highestBid;
            highestBidder = msg.sender;
            highestBid = _value;
        } else if (_value > secondHighestBid) {
            secondHighestBidder = msg.sender;
            secondHighestBid = _value;
        }

        emit BidRevealed(msg.sender, _value);
    }

    function endAuction() external onlyAfter(revealEnd) {
        require(!ended, "Already ended");
        ended = true;

        uint256 winnerPays = secondHighestBid > 0 ? secondHighestBid : highestBid;

        if (highestBidder != address(0)) {
            payable(seller).transfer(winnerPays);

            uint256 refund = bids[highestBidder].deposit - winnerPays;
            if (refund > 0) {
                payable(highestBidder).transfer(refund);
            }
        }

        emit AuctionEnded(highestBidder, winnerPays);
    }

    function withdraw() external onlyAfter(revealEnd) {
        require(msg.sender != highestBidder, "Winner cannot withdraw");

        Bid storage bid = bids[msg.sender];
        uint256 amount = bid.deposit;
        require(amount > 0, "Nothing to withdraw");

        bid.deposit = 0;
        payable(msg.sender).transfer(amount);
    }
}