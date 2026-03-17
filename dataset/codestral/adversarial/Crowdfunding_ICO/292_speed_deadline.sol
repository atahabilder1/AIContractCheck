// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    uint256 public goal;
    uint256 public deadline;
    uint256 public amountRaised;
    mapping(address => uint256) public contributions;
    bool public isActive = true;

    constructor(uint256 _goal, uint256 _deadline) {
        goal = _goal;
        deadline = _deadline;
    }

    function contribute() public payable {
        require(isActive && msg.value > 0 && now <= deadline);
        contributions[msg.sender] += msg.value;
        amountRaised += msg.value;
    }

    function withdraw() public {
        require(isActive && now >= deadline && amountRaised < goal);
        uint256 contribution = contributions[msg.sender];
        if (contribution > 0) {
            payable(msg.sender).transfer(contribution);
            contributions[msg.sender] = 0;
            amountRaised -= contribution;
        }
    }

    function finalize() public {
        require(isActive && now >= deadline);
        isActive = false;
        if (amountRaised < goal) {
            for (address contributor in contributions) {
                payable(contributor).transfer(contributions[contributor]);
            }
        }
    }
}