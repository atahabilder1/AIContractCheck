// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 stretchGoal;
        uint256 deadline;
        uint256 amountRaised;
        bool completed;
        bool stretchCompleted;
        uint256 totalContributors;
        mapping(address => uint256) contributions;
    }

    struct Token {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
    }

    Token public projectToken;
    Campaign[] public campaigns;
    uint256 public tokenPrice; // in wei

    event CampaignCreated(uint256 campaignId, address creator, string title, uint256 goal, uint256 deadline);
    event Funded(uint256 campaignId, address funder, uint256 amount);
    event CampaignCompleted(uint256 campaignId, bool reachedGoal, bool reachedStretchGoal);
    event TokensClaimed(uint256 campaignId, address funder, uint256 amount);

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Not the campaign creator");
        _;
    }

    constructor(string memory _tokenName, string memory _tokenSymbol, uint8 _tokenDecimals, uint256 _initialSupply, uint256 _tokenPrice) {
        projectToken.name = _tokenName;
        projectToken.symbol = _tokenSymbol;
        projectToken.decimals = _tokenDecimals;
        projectToken.totalSupply = _initialSupply * (10 ** uint256(_tokenDecimals));
        projectToken.balances[msg.sender] = projectToken.totalSupply;
        tokenPrice = _tokenPrice;
    }

    function createCampaign(string memory _title, string memory _description, uint256 _goal, uint256 _stretchGoal, uint256 _deadline) public {
        require(_goal < _stretchGoal, "Goal must be less than stretch goal");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        Campaign memory newCampaign = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            stretchGoal: _stretchGoal,
            deadline: _deadline,
            amountRaised: 0,
            completed: false,
            stretchCompleted: false,
            totalContributors: 0
        });

        campaigns.push(newCampaign);
        emit CampaignCreated(campaigns.length - 1, msg.sender, _title, _goal, _deadline);
    }

    function fundCampaign(uint256 _campaignId) public payable {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Amount must be greater than 0");

        campaign.amountRaised += msg.value;
        if (campaign.contributions[msg.sender] == 0) {
            campaign.totalContributors++;
        }
        campaign.contributions[msg.sender] += msg.value;

        emit Funded(_campaignId, msg.sender, msg.value);
    }

    function checkCampaignCompletion(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(!campaign.completed, "Campaign already checked");

        if (campaign.amountRaised >= campaign.stretchGoal) {
            campaign.stretchCompleted = true;
        } else if (campaign.amountRaised >= campaign.goal) {
            campaign.completed = true;
        } else {
            payable(campaign.creator).transfer(campaign.amountRaised);
            campaign.amountRaised = 0;
        }

        emit CampaignCompleted(_campaignId, campaign.completed, campaign.stretchCompleted);
    }

    function claimTokens(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.completed || campaign.stretchCompleted, "Campaign not completed");
        require(campaign.contributions[msg.sender] > 0, "No contribution made");

        uint256 tokensToClaim = (campaign.contributions[msg.sender] / tokenPrice) * (10 ** uint256(projectToken.decimals));
        projectToken.balances[msg.sender] += tokensToClaim;
        projectToken.totalSupply -= tokensToClaim;
        campaign.contributions[msg.sender] = 0;

        emit TokensClaimed(_campaignId, msg.sender, tokensToClaim);
    }

    function transferTokens(address _to, uint256 _amount) public returns (bool) {
        require(projectToken.balances[msg.sender] >= _amount, "Insufficient balance");
        projectToken.balances[msg.sender] -= _amount;
        projectToken.balances[_to] += _amount;
        return true;
    }

    function approveTokens(address _spender, uint256 _amount) public returns (bool) {
        projectToken.allowances[msg.sender][_spender] = _amount;
        return true;
    }

    function transferFromTokens(address _from, address _to, uint256 _amount) public returns (bool) {
        require(projectToken.balances[_from] >= _amount, "Insufficient balance");
        require(projectToken.allowances[_from][msg.sender] >= _amount, "Allowance too low");

        projectToken.balances[_from] -= _amount;
        projectToken.allowances[_from][msg.sender] -= _amount;
        projectToken.balances[_to] += _amount;
        return true;
    }
}