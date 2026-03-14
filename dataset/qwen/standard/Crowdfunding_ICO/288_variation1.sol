// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BondingCurveCrowdfunding {
    uint256 public totalRaised;
    uint256 public initialPrice = 100; // Initial price of 1 token in wei
    uint256 public priceIncrement = 1; // Price increases by 1 wei per token bought
    uint256 public tokensSold;
    mapping(address => uint256) public contributions;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 price);

    function buyTokens() external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        uint256 tokensToBuy = calculateTokens(msg.value);
        require(tokensToBuy > 0, "Not enough funds to purchase tokens");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        tokensSold += tokensToBuy;

        emit TokensPurchased(msg.sender, tokensToBuy, currentPrice());
    }

    function calculateTokens(uint256 amount) public view returns (uint256) {
        uint256 totalPrice = 0;
        uint256 tokens = 0;
        uint256 price = initialPrice;

        while (totalPrice + price <= amount && tokens < amount / price) {
            totalPrice += price;
            price += priceIncrement;
            tokens++;
        }

        return tokens;
    }

    function currentPrice() public view returns (uint256) {
        return initialPrice + (priceIncrement * tokensSold);
    }

    function withdraw() external {
        require(msg.sender == address(this), "Only the contract can withdraw");
        payable(msg.sender).transfer(address(this).balance);
    }
}