// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BondingCurveCrowdfunding {
    uint256 public constant INITIAL_PRICE = 0.001 ether;
    uint256 public constant INCREMENT_PER_ETHER = 0.0001 ether;
    uint256 public totalContributions;
    uint256 public totalTokens;
    address public owner;
    
    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokenBalances;

    event Contribution(address indexed contributor, uint256 amount, uint256 tokensIssued);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function contribute() external payable {
        require(msg.value > 0, "Must contribute more than 0");

        uint256 tokensToIssue = calculateTokens(msg.value);
        contributions[msg.sender] += msg.value;
        totalContributions += msg.value;
        tokenBalances[msg.sender] += tokensToIssue;
        totalTokens += tokensToIssue;

        emit Contribution(msg.sender, msg.value, tokensToIssue);
    }

    function calculateTokens(uint256 amount) public view returns (uint256) {
        uint256 runningTotal = totalContributions;
        uint256 tokensIssued = 0;

        while (amount > 0) {
            uint256 currentPrice = INITIAL_PRICE + (runningTotal * INCREMENT_PER_ETHER) / 1 ether;
            uint256 maxTokensAtCurrentPrice = amount / currentPrice;
            tokensIssued += maxTokensAtCurrentPrice;
            amount -= maxTokensAtCurrentPrice * currentPrice;
            runningTotal += maxTokensAtCurrentPrice * currentPrice;
        }

        return tokensIssued;
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function tokensOf(address contributor) external view returns (uint256) {
        return tokenBalances[contributor];
    }
}