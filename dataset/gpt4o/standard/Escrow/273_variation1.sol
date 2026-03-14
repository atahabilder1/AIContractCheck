// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowForFreelanceServices {
    address public client;
    address public freelancer;
    uint256 public totalAmount;
    uint256 public milestoneCount;
    uint256 public currentMilestone;
    mapping(uint256 => uint256) public milestoneAmounts;
    mapping(uint256 => bool) public milestoneApproved;

    modifier onlyClient() {
        require(msg.sender == client, "Only client can perform this action");
        _;
    }

    modifier onlyFreelancer() {
        require(msg.sender == freelancer, "Only freelancer can perform this action");
        _;
    }

    modifier validMilestone(uint256 _milestone) {
        require(_milestone > 0 && _milestone <= milestoneCount, "Invalid milestone");
        _;
    }

    constructor(address _freelancer, uint256[] memory _milestoneAmounts) payable {
        require(_freelancer != address(0), "Freelancer address cannot be zero");
        require(_milestoneAmounts.length > 0, "There must be at least one milestone");

        client = msg.sender;
        freelancer = _freelancer;
        milestoneCount = _milestoneAmounts.length;
        totalAmount = msg.value;

        uint256 sum = 0;
        for (uint256 i = 0; i < milestoneCount; i++) {
            milestoneAmounts[i + 1] = _milestoneAmounts[i];
            sum += _milestoneAmounts[i];
        }

        require(sum == totalAmount, "Sum of milestone amounts must equal total amount");
    }

    function approveMilestone(uint256 _milestone) public onlyClient validMilestone(_milestone) {
        require(!milestoneApproved[_milestone], "Milestone already approved");
        require(_milestone == currentMilestone + 1, "Milestones must be approved in order");

        milestoneApproved[_milestone] = true;
        currentMilestone = _milestone;

        uint256 amountToRelease = milestoneAmounts[_milestone];
        payable(freelancer).transfer(amountToRelease);
    }

    function withdraw() public onlyClient {
        require(currentMilestone == milestoneCount, "All milestones must be approved before withdrawal");
        uint256 remainingAmount = address(this).balance;
        payable(client).transfer(remainingAmount);
    }

    function getMilestoneAmount(uint256 _milestone) public view validMilestone(_milestone) returns (uint256) {
        return milestoneAmounts[_milestone];
    }
}