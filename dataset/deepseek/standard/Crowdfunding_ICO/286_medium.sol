// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

contract CrowdfundingPlatform {
    struct Campaign {
        address payable beneficiary;
        uint256 fundingGoal;
        uint256 fundingEndTime;
        uint256 amountRaised;
        bool goalReached;
        bool ended;
        uint256 stretchGoal;
        uint256 totalTokens;
        mapping(address => uint256) contributions;
    }

    Campaign[] public campaigns;
    mapping(uint256 => address) public campaignToOwner;
    IERC20 public token;

    event CampaignCreated(uint256 indexed campaignId, address indexed owner, address beneficiary, uint256 fundingGoal, uint256 fundingEndTime, uint256 stretchGoal);
    event ContributionReceived(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event GoalReached(uint256 indexed campaignId);
    event CampaignEnded(uint256 indexed campaignId);

    modifier onlyOwner(uint256 campaignId) {
        require(campaignToOwner[campaignId] == msg.sender, "Only owner can call this function");
        _;
    }

    function createCampaign(address payable beneficiary, uint256 fundingGoal, uint256 fundingEndTime, uint256 stretchGoal, uint256 totalTokens) public {
        Campaign storage campaign = campaigns.push();
        campaign.beneficiary = beneficiary;
        campaign.fundingGoal = fundingGoal;
        campaign.fundingEndTime = fundingEndTime;
        campaign.goalReached = false;
        campaign.ended = false;
        campaign.stretchGoal = stretchGoal;
        campaign.totalTokens = totalTokens;

        campaignToOwner[campaigns.length - 1] = msg.sender;

        emit CampaignCreated(campaigns.length - 1, msg.sender, beneficiary, fundingGoal, fundingEndTime, stretchGoal);
    }

    function contribute(uint256 campaignId) public payable {
        Campaign storage campaign = campaigns[campaignId];
        require(block.timestamp < campaign.fundingEndTime, "Funding period has ended");
        require(!campaign.ended, "Campaign has already ended");

        campaign.contributions[msg.sender] += msg.value;
        campaign.amountRaised += msg.value;

        emit ContributionReceived(campaignId, msg.sender, msg.value);

        if (campaign.amountRaised >= campaign.fundingGoal && !campaign.goalReached) {
            campaign.goalReached = true;
            emit GoalReached(campaignId);
        }

        if (campaign.amountRaised >= campaign.stretchGoal && !campaign.ended) {
            if (token.transfer(msg.sender, campaign.totalTokens)) {
                campaign.ended = true;
                emit CampaignEnded(campaignId);
            }
        }
    }

    function finalizeCampaign(uint256 campaignId) public onlyOwner(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        require(block.timestamp >= campaign.fundingEndTime, "Funding period has not ended");
        require(!campaign.goalReached || campaign.amountRaised >= campaign.stretchGoal, "Goal not reached and stretch goal not met");
        require(!campaign.ended, "Campaign has already ended");

        uint256 amount = campaign.amountRaised;
        campaign.beneficiary.transfer(amount);
        campaign.ended = true;

        emit CampaignEnded(campaignId);
    }

    function setTokenContract(address _token) public {
        token = IERC20(_token);
    }
}