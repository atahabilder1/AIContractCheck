// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic English Auction
contract EnglishAuction {
    address public seller;
    address public nftContract;
    uint256 public tokenId;
    uint256 public startPrice;
    uint256 public endTime;
    address public highestBidder;
    uint256 public highestBid;
    bool public ended;

    mapping(address => uint256) public pendingReturns;

    event Bid(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event Withdrawal(address indexed bidder, uint256 amount);

    constructor(
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _duration
    ) {
        seller = msg.sender;
        nftContract = _nftContract;
        tokenId = _tokenId;
        startPrice = _startPrice;
        endTime = block.timestamp + _duration;
    }

    function bid() external payable {
        require(block.timestamp < endTime, "Auction ended");
        require(msg.value > highestBid, "Bid too low");
        require(msg.value >= startPrice, "Below start price");

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit Withdrawal(msg.sender, amount);
    }

    function endAuction() external {
        require(block.timestamp >= endTime, "Auction not ended");
        require(!ended, "Already ended");

        ended = true;

        if (highestBidder != address(0)) {
            IERC721(nftContract).transferFrom(seller, highestBidder, tokenId);
            payable(seller).transfer(highestBid);
        }

        emit AuctionEnded(highestBidder, highestBid);
    }

    function cancelAuction() external {
        require(msg.sender == seller, "Not seller");
        require(highestBidder == address(0), "Bids already placed");
        require(!ended, "Already ended");

        ended = true;
    }
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}
