// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    using SafeMath for uint256;

    struct Campaign {
        address payable owner;
        uint256 goal;
        uint256 amountRaised;
        bool isCompleted;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCount;

    constructor() {
        campaignCount = 0;
    }

    function createCampaign(uint256 _goal) public returns (uint256) {
        campaignCount++;
        campaigns[campaignCount] = Campaign({owner: msg.sender, goal: _goal, amountRaised: 0, isCompleted: false});
        return campaignCount;
    }

    function contribute(uint256 _id) public payable {
        Campaign storage camp = campaigns[_id];
        require(!camp.isCompleted, "Campaign has already been completed");
        camp.amountRaised += msg.value;
        if (camp.amountRaised >= camp.goal) completeCampaign(_id);
    }

    function withdraw(uint256 _id) public {
        Campaign storage camp = campaigns[_id];
        require(msg.sender == camp.owner, "Only the campaign owner can withdraw funds");
        require(!camp.isCompleted, "Funds have already been withdrawn");
        camp.owner.transfer(camp.amountRaised);
    }

    function completeCampaign(uint256 _id) internal {
        Campaign storage camp = campaigns[_id];
        if (camp.amountRaised >= camp.goal) {
            camp.isCompleted = true;
        }
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}