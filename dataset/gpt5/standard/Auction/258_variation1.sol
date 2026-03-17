// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/**
 * @title DutchAuction
 * @notice A simple Dutch auction for a single ERC721 token where the price starts high and decreases linearly over time
 *         at a configurable decay rate until someone buys it, subject to a minimum price floor.
 */
contract DutchAuction {
    // Immutable auction parameters
    IERC721 public immutable nft;
    uint256 public immutable tokenId;
    address payable public immutable seller;
    uint256 public immutable startPrice;            // Initial price in wei
    uint256 public immutable minPrice;              // Minimum price (floor) in wei
    uint256 public immutable decayRatePerSecond;    // Price decay in wei per second
    uint256 public immutable startTime;             // Auction start timestamp (seconds)

    // Auction state
    bool public settled;

    // Reentrancy guard
    bool private locked;

    // Errors
    error InvalidParams();
    error AuctionAlreadySettled();
    error AuctionNotStarted();
    error InsufficientPayment();
    error ETHTransferFailed();
    error Reentrancy();

    // Events
    event Purchased(address indexed buyer, uint256 pricePaid);
    event Settled(address indexed buyer, uint256 pricePaid);

    constructor(
        IERC721 _nft,
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _minPrice,
        uint256 _decayRatePerSecond,
        uint256 _startTime
    ) {
        if (
            address(_nft) == address(0) ||
            _startPrice < _minPrice ||
            _decayRatePerSecond == 0
        ) revert InvalidParams();

        nft = _nft;
        tokenId = _tokenId;
        seller = payable(msg.sender);
        startPrice = _startPrice;
        minPrice = _minPrice;
        decayRatePerSecond = _decayRatePerSecond;
        startTime = _startTime;

        // Transfer the NFT from seller to this contract for escrow (requires prior approval).
        _nft.transferFrom(msg.sender, address(this), _tokenId);
    }

    // Simple non-reentrancy modifier
    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    // Returns the current auction price based on linear decay down to minPrice.
    function currentPrice() public view returns (uint256) {
        if (block.timestamp <= startTime) {
            return startPrice;
        }

        uint256 elapsed = block.timestamp - startTime;

        // Compute decay, ensure it does not reduce price below minPrice
        uint256 totalPossibleDecay = startPrice - minPrice;
        uint256 decay = decayRatePerSecond * elapsed;

        if (decay >= totalPossibleDecay) {
            return minPrice;
        }
        return startPrice - decay;
    }

    // Purchase the NFT by paying at least the current price; any excess is refunded.
    function buy() external payable nonReentrant {
        if (settled) revert AuctionAlreadySettled();
        if (block.timestamp < startTime) revert AuctionNotStarted();

        uint256 price = currentPrice();
        if (msg.value < price) revert InsufficientPayment();

        settled = true;

        // Transfer NFT to buyer
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        // Send funds to seller
        (bool sentSeller, ) = seller.call{value: price}("");
        if (!sentSeller) revert ETHTransferFailed();

        // Refund any overpayment
        uint256 refund = msg.value - price;
        if (refund > 0) {
            (bool sentRefund, ) = payable(msg.sender).call{value: refund}("");
            if (!sentRefund) revert ETHTransferFailed();
        }

        emit Purchased(msg.sender, price);
        emit Settled(msg.sender, price);
    }

    // Helper: seconds elapsed since auction start (0 if not started yet).
    function timeElapsed() external view returns (uint256) {
        if (block.timestamp <= startTime) return 0;
        return block.timestamp - startTime;
    }

    // Prevent accidental ETH sends
    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}