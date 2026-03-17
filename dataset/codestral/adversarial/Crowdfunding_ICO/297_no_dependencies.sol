// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    uint public fundingGoal;
    mapping(address => uint) public contributions;
    bool public fundingComplete;

    constructor(uint _fundingGoal) {
        fundingGoal = _fundingGoal;
    }

    function contribute() public payable {
        require(!fundingComplete, "Funding goal has already been reached.");
        contributions[msg.sender] += msg.value;
        if (totalContributions() >= fundingGoal) {
            fundingComplete = true;
        }
    }

    function withdraw() public {
        require(fundingComplete, "Funding goal has not been reached yet.");
        uint contribution = contributions[msg.sender];
        require(contribution > 0, "You have not contributed to this campaign.");
        payable(msg.sender).transfer(contribution);
        contributions[msg.sender] = 0;
    }

    function totalContributions() public view returns (uint) {
        uint total = 0;
        for (address contributor in contributions) {
            total += contributions[contributor];
        }
        return total;
    }
}