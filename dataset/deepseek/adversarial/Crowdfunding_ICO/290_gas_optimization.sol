// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingICO {
    address public owner;
    uint256 public goal;
    uint256 public raisedAmount;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public rate;
    mapping(address => uint256) public contributions;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event GoalReached(uint256 amountRaised);
    event Refunded(address indexed contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(uint256 _goal, uint256 _startTime, uint256 _endTime, uint256 _rate) {
        require(_goal > 0, "Goal must be greater than 0");
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_rate > 0, "Rate must be greater than 0");

        owner = msg.sender;
        goal = _goal;
        startTime = _startTime;
        endTime = _endTime;
        rate = _rate;
    }

    function contribute() public payable {
        require(block.timestamp >= startTime, "Crowdfunding has not started yet");
        require(block.timestamp <= endTime, "Crowdfunding has ended");
        require(msg.value > 0, "Contribution must be greater than 0");

        contributions[msg.sender] += msg.value;
        raisedAmount += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    function finalize() public onlyOwner {
        require(block.timestamp >= endTime, "Crowdfunding period has not ended yet");
        require(raisedAmount >= goal, "Goal has not been reached");

        // Transfer funds to the owner
        payable(owner).transfer(address(this).balance);
    }

    function refund(address payable contributor) public onlyOwner {
        require(block.timestamp >= endTime, "Crowdfunding period has not ended yet");
        require(raisedAmount < goal, "Goal has been reached");

        uint256 contribution = contributions[contributor];
        if (contribution > 0) {
            contributions[contributor] = 0;
            raisedAmount -= contribution;
            payable(contributor).transfer(contribution);
            emit Refunded(contributor, contribution);
        }
    }

    function withdrawTokens(address tokenAddress) public onlyOwner {
        require(block.timestamp >= endTime, "Crowdfunding period has not ended yet");
        require(raisedAmount < goal, "Goal has been reached");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner, balance), "Token transfer failed");
    }
}