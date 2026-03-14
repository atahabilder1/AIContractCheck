// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint256 public targetAmount;
    uint256 public currentAmount;
    uint256 public tokenPrice;
    uint256 public constant INITIAL_TOKEN_PRICE = 1 ether; // 1 token = 1 ether initially
    uint256 public constant TOKEN_INCREMENT = 0.1 ether; // Increment the token price by 0.1 ether each contribution
    uint256 public constant TOKEN_CAP = 1000; // Maximum number of tokens

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokens;

    event Contribution(address indexed contributor, uint256 amount, uint256 tokens);
    event GoalReached(uint256 amountRaised);
    event GoalNotReached();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(uint256 _targetAmount) {
        owner = msg.sender;
        targetAmount = _targetAmount;
        tokenPrice = INITIAL_TOKEN_PRICE;
    }

    function contribute() public payable {
        require(currentAmount + msg.value <= targetAmount, "Goal already reached");

        uint256 contributionAmount = msg.value;
        uint256 tokensBought = contributionAmount / tokenPrice;

        if (tokensBought > 0) {
            contributions[msg.sender] += contributionAmount;
            tokens[msg.sender] += tokensBought;

            currentAmount += contributionAmount;

            if (currentAmount >= targetAmount) {
                emit GoalReached(currentAmount);
            }

            if (tokenPrice < INITIAL_TOKEN_PRICE && tokens[msg.sender] > TOKEN_CAP) {
                tokenPrice += TOKEN_INCREMENT;
            }

            emit Contribution(msg.sender, contributionAmount, tokensBought);
        }
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        payable(owner).transfer(address(this).balance);
    }

    function setTargetAmount(uint256 _targetAmount) public onlyOwner {
        targetAmount = _targetAmount;
    }

    function getContribution() public view returns (uint256) {
        return contributions[msg.sender];
    }

    function getTokens() public view returns (uint256) {
        return tokens[msg.sender];
    }
}