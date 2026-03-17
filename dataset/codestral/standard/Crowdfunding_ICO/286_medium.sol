// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrowdfundingPlatform is Ownable {
    IERC20 private token;

    struct Campaign {
        uint256 goal;
        uint256 deadline;
        mapping(address => uint256) contributions;
        uint256 stretchGoal;
        bool reachedStretchGoal;
    }

    mapping(uint256 => Campaign) campaigns;
    uint256 public campaignCount;

    constructor(IERC20 _token) {
        token = _token;
    }

    function createCampaign(uint256 _goal, uint256 _deadline, uint256 _stretchGoal) external onlyOwner {
        campaignCount++;
        campaigns[campaignCount] = Campaign(_goal, _deadline, mapping(address => uint256)(), _stretchGoal, false);
    }

    function contributeToCampaign(uint256 _campaignId, uint256 _amount) external {
        require(_campaignId <= campaignCount, "Invalid campaign ID");
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Funding deadline has passed");

        token.transferFrom(msg.sender, address(this), _amount);
        campaign.contributions[msg.sender] += _amount;

        if (getTotalContributed(_campaignId) >= campaign.stretchGoal && !campaign.reachedStretchGoal) {
            campaign.reachedStretchGoal = true;
            // Add stretch goal rewards logic here
        }
    }

    function getTotalContributed(uint256 _campaignId) public view returns (uint256) {
        Campaign memory campaign = campaigns[_campaignId];
        uint256 total = 0;
        for (address contributor in campaign.contributions) {
            total += campaign.contributions[contributor];
        }
        return total;
    }

    function claimTokens(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp > campaign.deadline, "Funding period is still active");
        uint256 contributedAmount = campaign.contributions[msg.sender];
        require(contributedAmount > 0, "No contribution found for this address");

        // Distribute tokens based on the contribution percentage and stretch goal rewards
    }
}