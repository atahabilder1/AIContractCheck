// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CrowdFunding {
    address public owner;
    uint256 public goalAmount;
    mapping(address => uint256) public contributions;
    bool public fundingOpen;

    constructor(uint256 _goalAmount) {
        owner = msg.sender;
        goalAmount = _goalAmount;
        fundingOpen = true;
    }

    function contribute() public payable {
        require(fundingOpen, "Funding is closed.");
        contributions[msg.sender] += msg.value;
    }

    function withdrawFunds() public {
        require(msg.sender == owner && !fundingOpen, "Only the owner can withdraw funds after funding is closed and goal reached.");
        uint256 totalContributions = 0;
        for (address contributor in contributions) {
            payable(contributor).transfer(contributions[contributor]);
            totalContributions += contributions[contributor];
        }
    }

    function closeFunding() public {
        require(msg.sender == owner, "Only the owner can close funding.");
        uint256 totalContributed = 0;
        for (address contributor in contributions) {
            totalContributed += contributions[contributor];
        }
        if (totalContributed >= goalAmount) {
            fundingOpen = false;
        } else {
            // If the goal is not reached, return the funds to contributors.
            withdrawFunds();
        }
    }
}