```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title DutchAuctionNFT
 * @dev An ERC721 contract implementing a Dutch auction mint.
 *      The price decreases at regular intervals until a reserve price is reached or all tokens are sold.
 */
contract DutchAuctionNFT is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public immutable MAX_SUPPLY;

    // Auction parameters
    uint256 public auctionStartTime;
    uint256 public startPrice;
    uint256 public reservePrice;
    uint256 public priceDecrementAmount;
    uint256 public immutable priceDecrementInterval; // Time in seconds between price decrements

    string private _baseTokenURI;

    event AuctionStarted(