// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DutchAuctionNFT is ERC721, Ownable {
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant AUCTION_START_PRICE = 1 ether;
    uint256 public constant AUCTION_END_PRICE = 0.1 ether;
    uint256 public constant PRICE_DECREMENT = 0.05 ether;
    uint256 public constant PRICE_DECREASE_INTERVAL = 10 minutes;

    uint256 public auctionStartTime;
    uint256 public totalMinted;

    constructor(uint256 _auctionStartTime) ERC721("DutchAuctionNFT", "DANFT") Ownable(msg.sender) {
        auctionStartTime = _auctionStartTime;
    }

    function getPrice() public view returns (uint256) {
        if (block.timestamp < auctionStartTime) {
            return AUCTION_START_PRICE;
        }

        uint256 elapsed = block.timestamp - auctionStartTime;
        uint256 steps = elapsed / PRICE_DECREASE_INTERVAL;
        uint256 discount = steps * PRICE_DECREMENT;

        if (discount >= AUCTION_START_PRICE - AUCTION_END_PRICE) {
            return AUCTION_END_PRICE;
        }

        return AUCTION_START_PRICE - discount;
    }

    function mint(uint256 quantity) external payable {
        require(block.timestamp >= auctionStartTime, "Auction not started");
        require(quantity > 0, "Quantity must be greater than 0");
        require(totalMinted + quantity <= MAX_SUPPLY, "Exceeds max supply");

        uint256 price = getPrice();
        uint256 totalCost = price * quantity;
        require(msg.value >= totalCost, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, totalMinted);
            totalMinted++;
        }

        if (msg.value > totalCost) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(success, "Refund failed");
        }
    }

    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }
}