// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DutchAuctionNFT is ERC721, Ownable, ReentrancyGuard {
    uint256 public constant AUCTION_STEP = 10 minutes;

    uint256 public immutable maxSupply;
    uint256 public immutable auctionStart;
    uint256 public immutable startPrice;
    uint256 public immutable endPrice;
    uint256 public immutable priceDropPerStep;

    uint256 private _nextTokenId = 1;
    string private _baseTokenURI;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 startPrice_,
        uint256 endPrice_,
        uint256 priceDropPerStep_,
        uint256 auctionStart_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(maxSupply_ > 0, "Invalid max supply");
        require(startPrice_ >= endPrice_, "Start < end");
        require(priceDropPerStep_ > 0, "Drop per step = 0");

        maxSupply = maxSupply_;
        startPrice = startPrice_;
        endPrice = endPrice_;
        priceDropPerStep = priceDropPerStep_;
        auctionStart = auctionStart_;
    }

    function getCurrentPrice() public view returns (uint256) {
        if (block.timestamp <= auctionStart) {
            return startPrice;
        }
        uint256 elapsed = block.timestamp - auctionStart;
        uint256 steps = elapsed / AUCTION_STEP;

        uint256 delta = startPrice - endPrice;
        if (steps == 0) {
            return startPrice;
        }
        // If enough steps have elapsed to reach or go below endPrice, return endPrice.
        uint256 maxSteps = (delta + priceDropPerStep - 1) / priceDropPerStep; // ceil(delta / drop)
        if (steps >= maxSteps) {
            return endPrice;
        }
        uint256 totalDrop = steps * priceDropPerStep;
        return startPrice - totalDrop;
    }

    function mint(uint256 quantity) external payable nonReentrant {
        require(quantity > 0, "Quantity = 0");
        require(block.timestamp >= auctionStart, "Auction not started");
        require(totalSupply() + quantity <= maxSupply, "Exceeds supply");

        uint256 price = getCurrentPrice();
        uint256 totalCost = price * quantity;
        require(msg.value >= totalCost, "Insufficient ETH");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, _nextTokenId++);
        }

        uint256 refund = msg.value - totalCost;
        if (refund > 0) {
            (bool ok, ) = msg.sender.call{value: refund}("");
            require(ok, "Refund failed");
        }
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId - 1;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function withdraw(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        uint256 bal = address(this).balance;
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "Withdraw failed");
    }
}