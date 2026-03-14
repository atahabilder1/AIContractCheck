// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VickreyAuction {
    address public owner;
    uint256 public auctionEndTime;
    bool public auctionEnded;

    struct Bid {
        uint256 bidAmount;
        uint256 revealTime;
        bool revealed;
    }

    mapping(address => Bid) public bids;
    address[] public bidders;
    uint256 public highestBid;
    uint256 public secondHighestBid;
    address public winner;

    uint256 public constant COMMITMENT_DURATION = 1 days; // Duration for submitting commitments
    uint256 public constant REVEAL_DURATION = 1 days; // Duration for revealing bids

    event BidCommitted(address indexed bidder);
    event BidRevealed(address indexed bidder, uint256 bidAmount);
    event AuctionEnded(address indexed winner, uint256 winningBid, uint256 pricePaid);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier onlyDuringCommitmentPhase() {
        require(block.timestamp < auctionEndTime - REVEAL_DURATION, "Commitment phase has ended.");
        require(!auctionEnded, "Auction has already ended.");
        _;
    }

    modifier onlyDuringRevealPhase() {
        require(block.timestamp >= auctionEndTime - REVEAL_DURATION && block.timestamp < auctionEndTime, "Reveal phase has ended or not started.");
        require(!auctionEnded, "Auction has already ended.");
        _;
    }

    modifier onlyAfterAuctionEnd() {
        require(auctionEnded, "Auction has not ended yet.");
        _;
    }

    constructor(uint256 _duration) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + _duration;
    }

    function commitBid(bytes32 _commitment) public payable onlyDuringCommitmentPhase {
        require(bids[msg.sender].bidAmount == 0, "You have already committed a bid."); // Check if not already committed
        require(msg.value == 0, "Commitment phase does not require payment."); // No payment during commitment

        bids[msg.sender] = Bid({
            bidAmount: 0, // Placeholder, will be revealed later
            revealTime: block.timestamp, // Timestamp of commitment
            revealed: false
        });
        bidders.push(msg.sender);

        emit BidCommitted(msg.sender);
    }

    function revealBid(uint256 _bidAmount) public payable onlyDuringRevealPhase {
        require(bids[msg.sender].bidAmount == 0 && !bids[msg.sender].revealed, "You have already revealed a bid or not committed.");
        require(_bidAmount > 0, "Bid amount must be greater than zero.");
        require(msg.value == _bidAmount, "Incorrect Ether sent for bid reveal."); // Payment is the bid amount

        bids[msg.sender].bidAmount = _bidAmount;
        bids[msg.sender].revealed = true;
        bids[msg.sender].revealTime = block.timestamp; // Actual reveal time

        emit BidRevealed(msg.sender, _bidAmount);
    }

    function endAuction() public onlyOwner {
        require(block.timestamp >= auctionEndTime, "Auction has not ended yet.");
        require(!auctionEnded, "Auction has already ended.");

        auctionEnded = true;

        highestBid = 0;
        secondHighestBid = 0;
        winner = address(0);

        for (uint i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            if (bids[bidder].revealed) {
                uint256 currentBid = bids[bidder].bidAmount;
                if (currentBid > highestBid) {
                    secondHighestBid = highestBid;
                    highestBid = currentBid;
                    winner = bidder;
                } else if (currentBid > secondHighestBid && currentBid < highestBid) {
                    secondHighestBid = currentBid;
                }
            }
        }

        // If no bids or only one bid, the winner pays 0
        uint256 pricePaid = (highestBid > 0 && secondHighestBid > 0) ? secondHighestBid : 0;

        // Refund excess Ether from the winner if they sent more than they owe
        if (winner != address(0) && address(this).balance >= highestBid) {
            // The winner is responsible for paying the pricePaid, which is the second highest bid.
            // We can handle this by letting the winner withdraw the difference.
            // For simplicity in this example, we'll assume the winner's sent Ether is managed externally or via a withdrawal function.
            // In a real-world scenario, you'd likely implement a withdrawal mechanism for the winner to claim their change.
        }

        emit AuctionEnded(winner, highestBid, pricePaid);
    }

    function withdrawWinnings() public {
        require(auctionEnded, "Auction has not ended yet.");
        require(msg.sender == winner, "Only the winner can withdraw.");
        require(winner != address(0), "No winner to withdraw.");

        uint256 pricePaid = (highestBid > 0 && secondHighestBid > 0) ? secondHighestBid : 0;
        uint256 amountToWithdraw = address(this).balance - pricePaid; // Assuming all bids were sent to the contract

        // Ensure the contract has enough balance to cover the winnings
        require(address(this).balance >= pricePaid, "Contract does not have enough funds to cover the price paid.");
        require(amountToWithdraw > 0, "No winnings to withdraw.");

        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed.");
    }

    // Function to allow bidders to reclaim their Ether if they didn't win or if the auction ends without a winner
    function reclaimBid() public {
        require(auctionEnded, "Auction has not ended yet.");
        require(msg.sender != winner, "Winner cannot reclaim their bid.");
        require(bids[msg.sender].bidAmount > 0, "You did not place a valid bid.");

        uint256 refundAmount = bids[msg.sender].bidAmount;
        bids[msg.sender].bidAmount = 0; // Reset bid to prevent multiple claims
        bids[msg.sender].revealed = false;

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund failed.");
    }

    // Helper function to check the status of a bidder
    function getBidStatus(address _bidder) public view returns (uint256 bidAmount, uint256 revealTime, bool revealed, bool committed) {
        Bid storage bid = bids[_bidder];
        return (bid.bidAmount, bid.revealTime, bid.revealed, bid.bidAmount > 0 || bid.revealed);
    }
}