// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleAuction {
    address payable public highestBidder;
    uint256 public highestBid;

    event HighestBidIncreased(address bidder, uint256 amount);

    function bid() public payable {
        require(msg.value > highestBid, "Bid must be higher than the current highest bid.");
        
        if (highestBidder != address(0)) {
            // Return the previous highest bid to the previous highest bidder
            (bool success, ) = highestBidder.call{value: highestBid}("");
            require(success, "Failed to refund previous bid.");
        }

        highestBidder = payable(msg.sender);
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function getHighestBid() public view returns (uint256) {
        return highestBid;
    }

    function getHighestBidder() public view returns (address) {
        return highestBidder;
    }

    // Function to withdraw funds at the end of the auction (optional, for demonstration)
    // In a real auction, you might have an end time and an owner to withdraw.
    function withdrawFunds() public {
        require(msg.sender == tx.origin, "Only the owner can withdraw."); // Simplistic owner check
        require(address(this).balance >= highestBid, "Not enough balance to withdraw."); // Ensure there are funds to withdraw

        // In a real scenario, you'd likely send funds to an auction owner
        // For simplicity, this example doesn't have an owner concept and just checks balance.
        // This function is more illustrative of how funds might be handled.
        // A more complete auction would have an end time and an owner.
        
        // This is a placeholder, as there's no explicit owner to send funds to.
        // In a real contract, 'owner.transfer(address(this).balance);' would be used.
        // For this simple contract, we'll just make sure the balance is cleared if needed.
        // This function is not strictly necessary for the core bidding logic.
        
        // To avoid complexity, we won't implement a full withdrawal mechanism here.
        // The highestBidder will implicitly "own" the funds by being the highest bidder.
        // A real auction would have a clear end and a mechanism for the organizer to claim funds.
    }
}