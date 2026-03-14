// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DutchAuctionERC721 is ERC721, Ownable {
    uint256 public constant TOTAL_SUPPLY = 100;
    uint256 public constant TIME_STEP = 10 minutes;
    uint256 public constant STARTING_PRICE = 1 ether;
    uint256 public constant END_PRICE = 0.1 ether;
    uint256 public startTime;
    uint256 public tokensSold;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        startTime = block.timestamp;
    }

    function price() public view returns (uint256) {
        if (tokensSold >= TOTAL_SUPPLY) return 0;
        uint256 elapsed = block.timestamp - startTime;
        uint256 stepCount = elapsed / TIME_STEP;
        uint256 priceStep = (STARTING_PRICE - END_PRICE) / (TOTAL_SUPPLY / TIME_STEP);
        uint256 currentPrice = STARTING_PRICE - (stepCount * priceStep);
        return currentPrice > END_PRICE ? currentPrice : END_PRICE;
    }

    function mint() external payable {
        require(tokensSold < TOTAL_SUPPLY, "All tokens have been sold");
        require(msg.value >= price(), "Insufficient funds");

        tokensSold++;
        _safeMint(msg.sender, tokensSold);

        if (msg.value > price()) {
            payable(msg.sender).transfer(msg.value - price());
        }
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}