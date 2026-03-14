// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DutchAuction {
    address payable public seller;
    uint256 public startPrice;
    uint256 public reservePrice;
    uint256 public startTime;
    uint256 public decayRate;
    uint256 public auctionDuration;
    bool public auctionEnded;

    event AuctionEnded(address winner, uint256 amount);

    constructor(
        uint256 _startPrice,
        uint256 _reservePrice,
        uint256 _decayRate,
        uint256 _auctionDuration
    ) {
        require(_startPrice > _reservePrice, "Start price must be greater than reserve price");
        require(_decayRate > 0, "Decay rate must be greater than zero");
        require(_auctionDuration > 0, "Auction duration must be greater than zero");

        seller = payable(msg.sender);
        startPrice = _startPrice;
        reservePrice = _reservePrice;
        decayRate = _decayRate;
        auctionDuration = _auctionDuration;
        startTime = block.timestamp;
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 elapsedTime = block.timestamp - startTime;
        uint256 priceDecrease = (elapsedTime * decayRate) / 1 ether;
        uint256 currentPrice = startPrice > priceDecrease ? startPrice - priceDecrease : reservePrice;
        return currentPrice > reservePrice ? currentPrice : reservePrice;
    }

    function buy() external payable {
        require(!auctionEnded, "Auction already ended");
        uint256 currentPrice = getCurrentPrice();
        require(msg.value >= currentPrice, "Insufficient ETH to buy at current price");

        auctionEnded = true;
        seller.transfer(msg.value);

        emit AuctionEnded(msg.sender, msg.value);
    }

    function auctionEndTime() public view returns (uint256) {
        return startTime + auctionDuration;
    }
}