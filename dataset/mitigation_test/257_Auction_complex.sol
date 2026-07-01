```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";

contract NFTAuctionHouse is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    enum AuctionType { ENGLISH, SEALED_BID, BATCH }
    enum AuctionStatus { ACTIVE, ENDED, CANCELLED }

    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        AuctionType auctionType;
        AuctionStatus status;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 currentBid;
        address highestBidder;
        uint256 startTime;
        uint256 endTime;
        uint256 extensionTime;
        address paymentToken; // address(0) for ETH
        uint256[] batchTokenIds;
        mapping(address => uint256) sealedBids;
        mapping(address => bytes32) sealedBidHashes;
        uint256 revealDeadline;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    uint256 public constant PLATFORM_FEE = 250; // 2.5%
    uint256 public constant MAX_EXTENSION_TIME = 15 minutes;
    uint256 public constant MIN_BID_INCREMENT = 100; // 1%
    uint256 public constant REVEAL_PERIOD = 24 hours;
    uint256 public constant BASIS_POINTS = 10000;

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(address => mapping(uint256 => uint256)) public pendingWithdrawals;
    
    uint256 public nextAuctionId = 1;
    uint256 public platformFeesCollected;
    
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        AuctionType auctionType,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 endTime
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 timestamp
    );
    
    event SealedBidCommitted(
        uint256 indexed auctionId,
        address indexed bidder,
        bytes32 bidHash
    );
    
    event SealedBidRevealed(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );
    
    event AuctionExtended(
        uint256 indexed auctionId,
        uint256 newEndTime
    );
    
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );
    
    event AuctionCancelled(uint256 indexed auctionId);
    
    modifier validAuction(uint256 auctionId) {
        require(auctionId > 0 && auctionId < nextAuctionId, "Invalid auction ID");
        _;
    }
    
    modifier onlyActiveBidding(uint256 auctionId) {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        _;
    }
    
    modifier onlySeller(uint256 auctionId) {
        require(auctions[auctionId].seller == msg.sender, "Not seller");
        _;
    }

    constructor() {}

    function createEnglishAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 duration,
        uint256 extensionTime,
        address paymentToken
    ) external nonReentrant returns (uint256) {
        require(nftContract != address(0), "Invalid NFT contract");
        require(startPrice > 0, "Start price must be > 0");
        require(reservePrice >= startPrice, "Reserve < start price");
        require(duration > 0 && duration <= 30 days, "Invalid duration");
        require(extensionTime <= MAX_EXTENSION_TIME, "Extension time too long");
        
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        
        uint256 auctionId = nextAuctionId++;
        Auction storage auction = auctions[auctionId];
        
        auction.seller = msg.sender;
        auction.nftContract = nftContract;
        auction.tokenId = tokenId;
        auction.auctionType = AuctionType.ENGLISH;
        auction.status = AuctionStatus.ACTIVE;
        auction.startPrice = startPrice;
        auction.reservePrice = reservePrice;
        auction.startTime = block.timestamp;
        auction.endTime = block.timestamp + duration;
        auction.extensionTime = extensionTime;
        auction.paymentToken = paymentToken;
        
        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftContract,
            tokenId,
            AuctionType.ENGLISH,
            startPrice,
            reservePrice,
            auction.endTime
        );
        
        return auctionId;
    }

    function createSealedBidAuction(
        address nftContract,
        uint256 tokenId,
        uint256 reservePrice,
        uint256 biddingDuration,
        address paymentToken
    ) external nonReentrant returns (uint256) {
        require(nftContract != address(0), "Invalid NFT contract");
        require(reservePrice > 0, "Reserve price must be > 0");
        require(biddingDuration > 0 && biddingDuration <= 30 days, "Invalid duration");
        
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        
        uint256 auctionId = nextAuctionId++;
        Auction storage auction = auctions[auctionId];
        
        auction.seller = msg.sender;
        auction.nftContract = nftContract;
        auction.tokenId = tokenId;
        auction.auctionType = AuctionType.SEALED_BID;
        auction.status = AuctionStatus.ACTIVE;
        auction.reservePrice = reservePrice;
        auction.startTime = block.timestamp;
        auction.endTime = block.timestamp + biddingDuration;
        auction.revealDeadline = auction.endTime + REVEAL_PERIOD;
        auction.paymentToken = paymentToken;
        
        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftContract,
            tokenId,
            AuctionType.SEALED_BID,
            0,
            reservePrice,
            auction.endTime
        );
        
        return auctionId;
    }

    function createBatchAuction(
        address nftContract,
        uint256[] calldata tokenIds,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 duration,
        address paymentToken
    ) external nonReentrant returns (uint256) {
        require(nftContract != address(0), "Invalid NFT contract");
        require(tokenIds.length > 1 && tokenIds.length <= 100, "Invalid batch size");
        require(startPrice > 0, "Start price must be > 0");
        require(reservePrice >= startPrice, "Reserve < start price");
        require(duration > 0 && duration <= 30 days, "Invalid duration");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenIds[i]);
        }
        
        uint256 auctionId = nextAuctionId++;
        Auction storage auction = auctions[auctionId];
        
        auction.seller = msg.sender;
        auction.nftContract = nftContract;
        auction.auctionType = AuctionType.BATCH;
        auction.status = AuctionStatus.ACTIVE;
        auction.startPrice = startPrice;
        auction.reservePrice = reservePrice;
        auction.startTime = block.timestamp;
        auction.endTime = block.timestamp + duration;
        auction.paymentToken = paymentToken;
        auction.batchTokenIds = tokenIds;
        
        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftContract,
            0,
            AuctionType.BATCH,
            startPrice,
            reservePrice,
            auction.endTime
        );
        
        return auctionId;
    }

    function placeBid(uint256 auctionId, uint256 bidAmount) 
        external 
        payable 
        nonReentrant 
        validAuction(auctionId) 
        onlyActiveBidding(auctionId) 
    {
        Auction storage auction = auctions[auctionId];
        require(auction.auctionType == AuctionType.ENGLISH || auction.auctionType == AuctionType.BATCH, "Wrong auction type");
        require(msg.sender != auction.seller, "Seller cannot bid");
        
        uint256 totalBid;
        if (auction.paymentToken == address(0)) {
            totalBid = msg.value;
            require(bidAmount == 0 || bidAmount == msg.value, "Bid amount mismatch");
        } else {
            require(msg.value == 0, "ETH not accepted");
            totalBid = bidAmount;
            require(totalBid > 0, "Bid amount must be > 0");
        }
        
        uint256 minBid = auction.currentBid == 0 ? auction.startPrice : 
            auction.currentBid + (auction.currentBid * MIN_BID_INCREMENT / BASIS_POINTS);
        require(totalBid >= minBid, "Bid too low");
        
        if (auction.paymentToken != address(0)) {
            IERC20(auction.paymentToken).safeTransferFrom(msg.sender, address(this), totalBid);
        }
        
        address previousBidder = auction.highestBidder;
        uint256 previousBid = auction.currentBid;
        
        auction.currentBid = totalBid;
        auction.highestBidder = msg.sender;
        
        if (previousBidder != address(0)) {
            pendingWithdrawals[previousBidder][auctionId] = previousBid;
        }
        
        auctionBids[auctionId].push(Bid({
            bidder: msg.sender,
            amount: totalBid,
            timestamp: block.timestamp
        }));
        
        if (auction.extensionTime > 0 && auction.endTime - block.timestamp < auction.extensionTime) {
            auction.endTime = block.timestamp + auction.extensionTime;
            emit AuctionExtended(auctionId, auction.endTime);
        }
        
        emit BidPlaced(auctionId, msg.sender, totalBid, block.timestamp);
    }

    function commitSealedBid(uint256 auctionId, bytes32 bidHash) 
        external 
        nonReentrant 
        validAuction(auctionId) 
        onlyActiveBidding(auctionId) 
    {
        Auction storage auction = auctions[auctionId];
        require(auction.auctionType == AuctionType.SEALED_BID, "Not sealed bid auction");
        require(msg.sender != auction.seller, "Seller cannot bid");
        require(auction.sealedBidHashes[msg.sender] == bytes32(0), "Bid already committed");
        
        auction.sealedBidHashes[msg.sender] = bidHash;
        
        emit SealedBidCommitted(auctionId, msg.sender, bidHash);
    }

    function revealSealedBid(uint256 auctionId, uint256 bidAmount, uint256 nonce) 
        external 
        payable 
        nonReentrant 
        validAuction(auctionId) 
    {
        Auction storage auction = auctions[auctionId];
        require(auction.auctionType == AuctionType.SEALED_BID, "Not sealed bid auction");
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp > auction.endTime, "Bidding period not ended");
        require(block.timestamp <= auction.revealDeadline, "Reveal period ended");
        
        bytes32 hash = keccak256(abi.encodePacked(bidAmount, nonce, msg.sender));
        require(auction.sealedBidHashes[msg.sender] == hash, "Invalid bid reveal");
        require(auction.sealedBids[msg.sender] == 0, "Already revealed");
        
        if (auction.paymentToken == address(0)) {
            require(msg.value == bidAmount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "ETH not accepted");
            IERC20(auction.paymentToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        }
        
        auction.sealedBids[msg.sender] = bidAmount;
        
        if (bidAmount > auction.currentBid && bidAmount >= auction.reservePrice) {
            if (auction.highestBidder != address(0)) {
                pendingWithdrawals[auction.highestBidder][auctionId] = auction.currentBid;
            }
            auction.currentBid = bidAmount;
            auction.highestBidder = msg.sender;
        } else {
            pendingWithdrawals[msg.sender][auctionId] = bidAmount;
        }
        
        emit SealedBidRevealed(auctionId, msg.sender, bidAmount);
    }

    function endAuction(uint256 auctionId) 
        external 
        nonReentrant 
        validAuction(auctionId) 
    {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        
        bool canEnd = false;
        if (auction.auctionType == AuctionType.SEALED_BID) {
            canEnd = block.timestamp > auction.revealDeadline;
        } else