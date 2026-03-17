// Source: Etherscan Verified (forge-flattened)
// Address: 0xd657686a1ce41720c4b29e13ea1d6cee1b4025b5
// Name: AuctionHouse
// Compiler: v0.8.7+commit.e28d00a7

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

// contracts/interfaces/IAuctionHouse.sol

/// @title Interface for Noun Auction Houses

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

interface IAuctionHouse {
    struct Auction {
        // ID for the squid DAO NFT (ERC721 token ID)
        uint256 squidDAONFTId;
        // The current highest bid amount
        uint256 amount;
        // The time that the auction started
        uint256 startTime;
        // The time that the auction is scheduled to end
        uint256 endTime;
        // The address of the current highest bid
        address payable bidder;
        // Whether or not the auction has been settled
        bool settled;
    }

    event AuctionCreated(
        uint256 indexed squidDAONFTId,
        uint256 startTime,
        uint256 endTime
    );

    event AuctionBid(
        uint256 indexed squidDAONFTId,
        address sender,
        uint256 value,
        bool extended
    );

    event AuctionExtended(uint256 indexed squidDAONFTId, uint256 endTime);

    event AuctionSettled(
        uint256 indexed squidDAONFTId,
        address winner,
        uint256 amount
    );

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionDurationUpdated(uint256 duration);

    event AuctionMinBidIncrementPercentageUpdated(
        uint256 minBidIncrementPercentage
    );

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function createBid(uint256 squidDAONFTId, uint256 amount) external payable;

    function pause() external;

    function unpause() external;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setReservePrice(uint256 reservePrice) external;

    function setDuration(uint256 duration) external;

    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage)
        external;
}