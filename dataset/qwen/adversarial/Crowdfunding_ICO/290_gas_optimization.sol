// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MinimalCrowdfunding {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public raisedAmount;
    bool public isClosed;

    event FundReceived(address contributor, uint amount);
    event CampaignClosed(bool success);

    constructor(uint _goal, uint _durationInDays) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    receive() external payable {
        require(!isClosed, "Campaign is closed");
        require(block.timestamp <= deadline, "Campaign has ended");
        raisedAmount += msg.value;
        emit FundReceived(msg.sender, msg.value);
    }

    function closeCampaign() external {
        require(msg.sender == owner, "Only owner can close the campaign");
        require(block.timestamp > deadline, "Campaign has not ended yet");
        isClosed = true;
        bool success = raisedAmount >= goal;
        emit CampaignClosed(success);
        if (success) {
            payable(owner).transfer(raisedAmount);
        }
    }
}