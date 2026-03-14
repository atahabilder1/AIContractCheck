// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public owner;
    uint256 public highestBid;
    address public highestBidder;
    uint256 public startTime;
    uint256 public endTime;
    bool public auctionEnded;

    event BidPlaced(address bidder, uint256 amount);
    event AuctionWon(address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp >= startTime && block.timestamp < endTime && !auctionEnded, "Auction is not active.");
        _;
    }

    modifier auctionNotEnded() {
        require(!auctionEnded, "Auction has already ended.");
        _;
    }

    constructor(uint256 _durationInSeconds) {
        owner = msg.sender;
        startTime = block.timestamp;
        endTime = startTime + _durationInSeconds;
        highestBid = 0;
        highestBidder = address(0);
        auctionEnded = false;
    }

    function placeBid() public payable auctionActive auctionNotEnded {
        require(msg.value > highestBid, "Bid must be higher than the current highest bid.");

        if (highestBidder != address(0)) {
            // Refund previous highest bidder
            (bool success, ) = payable(highestBidder).call{value: highestBid}("");
            require(success, "Refund failed.");
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, msg.value);
    }

    function endAuction() public onlyOwner auctionActive {
        require(block.timestamp >= endTime, "Auction has not ended yet.");
        auctionEnded = true;

        if (highestBidder != address(0)) {
            emit AuctionWon(highestBidder, highestBid);
            // The winner will claim their prize by sending a transaction with the winning bid amount
            // and the owner can then withdraw the funds.
        } else {
            // No bids were placed, return all funds to the owner if any were sent.
            if (address(this).balance > 0) {
                (bool success, ) = payable(owner).call{value: address(this).balance}("");
                require(success, "Owner withdrawal failed.");
            }
        }
    }

    // Owner can withdraw the winning bid amount after the auction has ended and been won.
    function withdrawWinnings() public onlyOwner auctionEnded {
        require(highestBidder != address(0), "No winner to withdraw from.");
        require(address(this).balance >= highestBid, "Insufficient balance to withdraw.");

        uint256 amountToWithdraw = highestBid;
        highestBid = 0; // Reset for potential future auctions if this contract were to be reused (though typically contracts are single-use for auctions)
        highestBidder = address(0);

        (bool success, ) = payable(owner).call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed.");
    }

    // Allow anyone to check the current status of the auction
    function getAuctionStatus() public view returns (
        address currentOwner,
        uint256 currentHighestBid,
        address currentHighestBidder,
        uint256 currentStartTime,
        uint256 currentEndTime,
        bool isAuctionEnded
    ) {
        return (owner, highestBid, highestBidder, startTime, endTime, auctionEnded);
    }

    // Fallback function to receive Ether if someone sends it directly without calling placeBid
    // This is generally not recommended for auction contracts as it bypasses logic.
    // However, for a standalone contract, it can be included for completeness if desired,
    // but should be carefully considered.
    // For this example, we will make it revert to enforce explicit bidding.
    receive() external payable {
        revert("Please use the placeBid function to bid.");
    }

    fallback() external payable {
        revert("Please use the placeBid function to bid.");
    }
}