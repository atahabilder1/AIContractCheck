// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HybridAuction {
    address payable public owner;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public reservePrice;
    uint256 public bidIncrement;

    address payable public highestBidder;
    uint256 public highestBid;

    enum AuctionType { English, Dutch }
    AuctionType public auctionType;

    bool public auctionEnded = false;

    event AuctionStarted(address indexed owner, uint256 startTime, uint256 endTime, uint256 reservePrice, uint256 bidIncrement, AuctionType auctionType);
    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionWon(address indexed winner, uint256 winningBid);
    event AuctionCancelled(address indexed owner);
    event RefundIssued(address indexed bidder, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier auctionActive() {
        require(!auctionEnded, "Auction has already ended.");
        require(block.timestamp >= startTime, "Auction has not started yet.");
        require(block.timestamp <= endTime, "Auction has ended.");
        _;
    }

    constructor(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _reservePrice,
        uint256 _bidIncrement,
        AuctionType _auctionType
    ) {
        owner = payable(msg.sender);
        startTime = _startTime;
        endTime = _endTime;
        reservePrice = _reservePrice;
        bidIncrement = _bidIncrement;
        auctionType = _auctionType;
    }

    function placeBid() external payable auctionActive {
        if (auctionType == AuctionType.English) {
            require(msg.value > highestBid, "Bid must be higher than the current highest bid.");
            require(msg.value >= highestBid + bidIncrement, "Bid must meet the minimum increment.");
            if (highestBidder != address(0)) {
                (bool success, ) = highestBidder.call{value: highestBid}("");
                require(success, "Failed to refund previous highest bidder.");
                emit RefundIssued(highestBidder, highestBid);
            }
            highestBidder = payable(msg.sender);
            highestBid = msg.value;
            emit BidPlaced(msg.sender, msg.value);
        } else { // Dutch Auction
            require(msg.value >= reservePrice, "Bid must be at least the reserve price.");
            // In a Dutch auction, the first bidder to meet the price wins.
            // The price decreases over time, but here we assume a fixed starting price and it's handled by external logic or contract deployment.
            // This implementation assumes the `reservePrice` is the *initial* price that decreases.
            // For a more dynamic Dutch auction, the `reservePrice` would need to be adjusted over time.
            // For simplicity, this version treats `reservePrice` as the *minimum acceptable bid* when the auction starts.
            require(msg.value >= highestBid, "Bid must be higher than or equal to the current effective price.");
            
            highestBidder = payable(msg.sender);
            highestBid = msg.value;
            emit BidPlaced(msg.sender, msg.value);
            
            // Since the first bidder wins in Dutch, we can end the auction immediately.
            // However, to allow for refunds if the owner cancels, we defer ending until the end time.
        }
    }

    function endAuction() public onlyOwner {
        require(!auctionEnded, "Auction has already ended.");
        auctionEnded = true;
        emit AuctionEnded(owner, block.timestamp);
    }

    function claimWinnings() external auctionActive {
        require(block.timestamp > endTime, "Auction is still active.");
        require(msg.sender == highestBidder, "Only the highest bidder can claim winnings.");
        require(highestBid >= reservePrice, "Winning bid did not meet the reserve price.");

        (bool success, ) = owner.call{value: highestBid}("");
        require(success, "Failed to transfer funds to owner.");

        emit AuctionWon(highestBidder, highestBid);
        auctionEnded = true; // Ensure it's marked as ended
    }

    function cancelAuction() public onlyOwner {
        require(!auctionEnded, "Auction has already ended.");
        auctionEnded = true;
        emit AuctionCancelled(owner);
    }

    function withdrawFunds() public onlyOwner {
        require(auctionEnded, "Auction must be ended to withdraw funds.");
        require(address(this).balance > 0, "No funds to withdraw.");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Failed to withdraw funds.");
    }

    // Fallback function to receive Ether
    receive() external payable {}
    fallback() external payable {}
}