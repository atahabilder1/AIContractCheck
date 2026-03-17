// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    uint256 public constant INITIAL_SUPPLY = 1000000 * (10 ** 18); // Total supply of tokens
    uint256 public constant INITIAL_PRICE = 1 ether; // Initial token price in Ether
    uint256 private totalEtherRaised;
    mapping(address => uint256) public contributorTokens;

    function contribute() external payable {
        require(msg.value > 0, "Contribution amount must be greater than zero");

        uint256 tokensToIssue = calculateTokens(msg.value);
        totalEtherRaised += msg.value;
        contributorTokens[msg.sender] += tokensToIssue;

        // Transfer ERC-20 tokens to the contributor
    }

    function calculateTokens(uint256 etherAmount) internal view returns (uint256) {
        uint256 currentPrice = INITIAL_PRICE * (INITIAL_SUPPLY - totalEtherRaised) / INITIAL_SUPPLY;
        return etherAmount * (10 ** 18) / currentPrice;
    }
}