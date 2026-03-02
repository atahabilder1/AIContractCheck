// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic Crowdfunding/ICO Contract
contract Crowdfunding {
    address public owner;
    address public token;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalRaised;
    uint256 public tokenPrice; // tokens per ETH
    bool public finalized;
    bool public goalReached;

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokensClaimed;

    event Contribution(address indexed contributor, uint256 amount);
    event GoalReached(uint256 totalRaised);
    event Refund(address indexed contributor, uint256 amount);
    event TokensClaimed(address indexed user, uint256 amount);
    event Finalized(bool success);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _token,
        uint256 _goal,
        uint256 _duration,
        uint256 _tokenPrice
    ) {
        owner = msg.sender;
        token = _token;
        goal = _goal;
        deadline = block.timestamp + _duration;
        tokenPrice = _tokenPrice;
    }

    function contribute() external payable {
        require(block.timestamp < deadline, "Campaign ended");
        require(msg.value > 0, "Must contribute > 0");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contribution(msg.sender, msg.value);

        if (totalRaised >= goal && !goalReached) {
            goalReached = true;
            emit GoalReached(totalRaised);
        }
    }

    function claimTokens() external {
        require(finalized && goalReached, "Cannot claim yet");
        require(contributions[msg.sender] > 0, "No contribution");
        require(tokensClaimed[msg.sender] == 0, "Already claimed");

        uint256 tokens = contributions[msg.sender] * tokenPrice;
        tokensClaimed[msg.sender] = tokens;
        IERC20(token).transfer(msg.sender, tokens);

        emit TokensClaimed(msg.sender, tokens);
    }

    function refund() external {
        require(block.timestamp >= deadline, "Campaign not ended");
        require(!goalReached, "Goal was reached");
        require(contributions[msg.sender] > 0, "No contribution");

        uint256 amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit Refund(msg.sender, amount);
    }

    function finalize() external onlyOwner {
        require(block.timestamp >= deadline || goalReached, "Cannot finalize yet");
        require(!finalized, "Already finalized");

        finalized = true;

        if (goalReached) {
            payable(owner).transfer(address(this).balance);
        }

        emit Finalized(goalReached);
    }

    function withdrawUnsoldTokens() external onlyOwner {
        require(finalized, "Not finalized");
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, balance);
    }

    function getContribution(address user) external view returns (uint256) {
        return contributions[user];
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
