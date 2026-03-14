// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingICO {
    address public owner;
    uint256 public targetAmount;
    uint256 public currentAmount;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public rate;

    mapping(address => uint256) public contributions;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event GoalReached(address indexed beneficiary, uint256 amount);
    event Refunded(address indexed beneficiary, uint256 amount);

    constructor(uint256 _targetAmount, uint256 _durationInDays, uint256 _rate) {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0 days");
        require(_rate > 0, "Rate must be greater than 0");

        owner = msg.sender;
        targetAmount = _targetAmount;
        startTime = block.timestamp;
        endTime = startTime + _durationInDays * 1 days;
        rate = _rate;
    }

    function contribute() public payable {
        require(block.timestamp < endTime, "Contribution period has ended");
        require(msg.value > 0, "Contribution amount must be greater than 0");

        contributions[msg.sender] += msg.value;
        currentAmount += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    function finalize() public {
        require(block.timestamp >= endTime, "Contribution period is still ongoing");
        require(currentAmount >= targetAmount, "Target amount not reached");

        // Transfer funds to the owner
        payable(owner).transfer(address(this).balance);

        emit GoalReached(owner, targetAmount);
    }

    function refund(address payable contributor) public {
        require(block.timestamp >= endTime, "Contribution period is still ongoing");
        require(currentAmount < targetAmount, "Target amount reached");

        uint256 contribution = contributions[contributor];
        require(contribution > 0, "No contribution to refund");

        // Refund the contribution
        (bool success, ) = contributor.call{value: contribution}("");
        require(success, "Refund transfer failed");

        contributions[contributor] = 0;

        emit Refunded(contributor, contribution);
    }
}