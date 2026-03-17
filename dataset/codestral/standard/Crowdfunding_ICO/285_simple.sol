// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CrowdFunding {
    uint public fundingGoal;
    mapping(address => uint) public contributions;
    bool public fundingReached;

    constructor(uint _fundingGoal) {
        fundingGoal = _fundingGoal;
        fundingReached = false;
    }

    function contribute() public payable {
        require(!fundingReached, "Funding goal already reached");
        contributions[msg.sender] += msg.value;
        if (getTotalContributions() >= fundingGoal) {
            fundingReached = true;
        }
    }

    function getTotalContributions() public view returns(uint) {
        uint total = 0;
        for (address contributor in contributions) {
            total += contributions[contributor];
        }
        return total;
    }

    function withdraw() public {
        require(!fundingReached, "Funding goal not reached yet");
        uint contribution = contributions[msg.sender];
        if (contribution > 0) {
            msg.sender.transfer(contribution);
            contributions[msg.sender] = 0;
        }
    }
}