// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    uint256 public goalAmount;
    mapping(address => uint256) public contributions;
    bool public fundingActive = true;

    constructor(uint256 _goalAmount) {
        goalAmount = _goalAmount;
    }

    function contribute() public payable {
        require(fundingActive, "Funding is not active.");
        contributions[msg.sender] += msg.value;
    }

    function withdraw() public {
        require(fundingActive == false && contributions[msg.sender] > 0, "Withdrawal conditions not met.");
        uint256 amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function finalizeCampaign() public {
        require(address(this).balance >= goalAmount, "Goal amount not reached.");
        fundingActive = false;
    }
}