// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    struct Campaign {
        uint id;
        string name;
        uint goal;
        uint deadline;
        uint raised;
        address payable beneficiary;
        mapping(address => uint) contributions;
        mapping(address => bool) contributors;
    }

    struct StretchGoal {
        uint id;
        uint amount;
        uint deadline;
        bool achieved;
    }

    mapping(uint => Campaign) public campaigns;
    mapping(uint => StretchGoal) public stretchGoals;

    event NewCampaign(uint id, string name, uint goal, uint deadline, address payable beneficiary);
    event Contribution(uint campaignId, address contributor, uint amount);
    event StretchGoalReached(uint campaignId, uint stretchGoalId, uint amount);

    function createCampaign(string memory name, uint goal, uint deadline, address payable beneficiary) public {
        Campaign memory newCampaign = Campaign(name, goal, deadline, beneficiary);
        campaigns[++campaigns.length] = newCampaign;
        emit NewCampaign(campaigns.length, name, goal, deadline, beneficiary);
    }

    function contribute(uint campaignId, address contributor, uint amount) public {
        require(campaigns[campaignId].raised < campaigns[campaignId].goal, "Campaign has already reached its goal");
        require(amount > 0, "Invalid contribution amount");
        campaigns[campaignId].raised += amount;
        campaigns[campaignId].contributions[contributor] += amount;
        campaigns[campaignId].contributors[contributor] = true;
        emit Contribution(campaignId, contributor, amount);
    }

    function createStretchGoal(uint campaignId, uint amount, uint deadline) public {
        require(campaigns[campaignId].raised < campaigns[campaignId].goal, "Campaign has already reached its goal");
        require(amount > 0, "Invalid stretch goal amount");
        stretchGoals[++stretchGoals.length] = StretchGoal(campaignId, amount, deadline);
        emit StretchGoalReached(campaignId, stretchGoals.length, amount);
    }

    function getStretchGoals(uint campaignId) public view returns (StretchGoal[] memory) {
        StretchGoal[] memory stretchGoals = new StretchGoal[stretchGoals.length];
        for (uint i = 0; i < stretchGoals.length; i++) {
            if (stretchGoals[i].campaignId == campaignId) {
                stretchGoals[i] = stretchGoals[i];
            }
        }
        return stretchGoals;
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory campaigns = new Campaign[campaigns.length];
        for (uint i = 0; i < campaigns.length; i++) {
            campaigns[i] = campaigns[i];
        }
        return campaigns;
    }

    function getCampaign(uint campaignId) public view returns (Campaign memory) {
        require(campaigns[campaignId].raised < campaigns[campaignId].goal, "Campaign has already reached its goal");
        return campaigns[campaignId];
    }
}