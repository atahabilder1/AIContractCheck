// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Crowdfunding is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Campaign {
        address creator;
        uint256 goal; // in USD (18 decimals)
        uint256 raised; // in USD (18 decimals)
        uint256 deadline;
        bool active;
        bool goalReached;
        mapping(address => uint256) contributions; // in USD
    }

    struct PriceOracle {
        AggregatorV3Interface priceFeed;
        uint8 decimals;
        bool active;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(address => PriceOracle) public oracles; // token address => oracle
    
    uint256 public campaignCounter;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MAX_CAMPAIGN_DURATION = 365 days;
    uint256 public constant MIN_GOAL = 100 * 1e18; // $100 minimum
    uint256 public constant MAX_GOAL = 10000000 * 1e18; // $10M maximum

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 goal,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        address token,
        uint256 tokenAmount,
        uint256 usdAmount
    );
    
    event CampaignFinalized(
        uint256 indexed campaignId,
        bool goalReached,
        uint256 totalRaised
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed recipient,
        uint256 amount
    );

    event OracleUpdated(address indexed token, address indexed oracle);

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Invalid campaign ID");
        require(campaigns[_campaignId].active, "Campaign not active");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Not campaign creator");
        _;
    }

    constructor() {
        // ETH/USD oracle placeholder - replace with actual Chainlink oracle address
        oracles[address(0)] = PriceOracle({
            priceFeed: AggregatorV3Interface(address(0)),
            decimals: 8,
            active: false
        });
    }

    function createCampaign(
        uint256 _goalUSD,
        uint256 _durationDays
    ) external returns (uint256) {
        require(_goalUSD >= MIN_GOAL && _goalUSD <= MAX_GOAL, "Invalid goal amount");
        require(_durationDays > 0 && _durationDays <= MAX_CAMPAIGN_DURATION / 1 days, "Invalid duration");

        uint256 campaignId = campaignCounter++;
        Campaign storage campaign = campaigns[campaignId];
        
        campaign.creator = msg.sender;
        campaign.goal = _goalUSD;
        campaign.raised = 0;
        campaign.deadline = block.timestamp + (_durationDays * 1 days);
        campaign.active = true;
        campaign.goalReached = false;

        emit CampaignCreated(campaignId, msg.sender, _goalUSD, campaign.deadline);
        return campaignId;
    }

    function contributeETH(uint256 _campaignId) 
        external 
        payable 
        nonReentrant 
        validCampaign(_campaignId) 
    {
        require(msg.value > 0, "Must send ETH");
        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign ended");

        uint256 usdAmount = _getETHPriceInUSD(msg.value);
        require(usdAmount > 0, "Invalid USD conversion");

        Campaign storage campaign = campaigns[_campaignId];
        campaign.contributions[msg.sender] += usdAmount;
        campaign.raised += usdAmount;

        if (campaign.raised >= campaign.goal) {
            campaign.goalReached = true;
        }

        emit ContributionMade(_campaignId, msg.sender, address(0), msg.value, usdAmount);
    }

    function contributeToken(
        uint256 _campaignId,
        address _token,
        uint256 _amount
    ) 
        external 
        nonReentrant 
        validCampaign(_campaignId) 
    {
        require(_token != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater than 0");
        require(oracles[_token].active, "Token oracle not supported");
        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign ended");

        uint256 usdAmount = _getTokenPriceInUSD(_token, _amount);
        require(usdAmount > 0, "Invalid USD conversion");

        Campaign storage campaign = campaigns[_campaignId];
        
        // Transfer tokens from contributor
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        campaign.contributions[msg.sender] += usdAmount;
        campaign.raised += usdAmount;

        if (campaign.raised >= campaign.goal) {
            campaign.goalReached = true;
        }

        emit ContributionMade(_campaignId, msg.sender, _token, _amount, usdAmount);
    }

    function finalizeCampaign(uint256 _campaignId) 
        external 
        nonReentrant 
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp > campaign.deadline || campaign.goalReached, "Campaign still active");

        campaign.active = false;

        emit CampaignFinalized(_campaignId, campaign.goalReached, campaign.raised);
    }

    function withdrawFunds(uint256 _campaignId) 
        external 
        nonReentrant 
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.active, "Campaign still active");
        require(campaign.goalReached, "Goal not reached");

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = payable(msg.sender).call{value: ethBalance}("");
            require(success, "ETH transfer failed");
            emit FundsWithdrawn(_campaignId, msg.sender, ethBalance);
        }
    }

    function withdrawTokens(uint256 _campaignId, address _token) 
        external 
        nonReentrant 
        onlyCampaignCreator(_campaignId)
    {
        require(_token != address(0), "Invalid token address");
        
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.active, "Campaign still active");
        require(campaign.goalReached, "Goal not reached");

        uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
        if (tokenBalance > 0) {
            IERC20(_token).safeTransfer(msg.sender, tokenBalance);
            emit FundsWithdrawn(_campaignId, msg.sender, tokenBalance);
        }
    }

    function refund(uint256 _campaignId) 
        external 
        nonReentrant 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.active, "Campaign still active");
        require(!campaign.goalReached, "Goal was reached");
        require(campaign.contributions[msg.sender] > 0, "No contribution found");

        uint256 contributionUSD = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;

        // Simplified refund - in production, would need to track individual token contributions
        uint256 ethRefund = _getUSDPriceInETH(contributionUSD);
        if (ethRefund > 0 && address(this).balance >= ethRefund) {
            (bool success, ) = payable(msg.sender).call{value: ethRefund}("");
            require(success, "Refund failed");
        }
    }

    function setOracle(address _token, address _oracle, uint8 _decimals) 
        external 
        onlyOwner 
    {
        require(_oracle != address(0), "Invalid oracle address");
        require(_decimals > 0, "Invalid decimals");

        oracles[_token] = PriceOracle({
            priceFeed: AggregatorV3Interface(_oracle),
            decimals: _decimals,
            active: true
        });

        emit OracleUpdated(_token, _oracle);
    }

    function getCampaignDetails(uint256 _campaignId) 
        external 
        view 
        returns (
            address creator,
            uint256 goal,
            uint256 raised,
            uint256 deadline,
            bool active,
            bool goalReached
        ) 
    {
        require(_campaignId < campaignCounter, "Invalid campaign ID");
        Campaign storage campaign = campaigns[_campaignId];
        
        return (
            campaign.creator,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.active,
            campaign.goalReached
        );
    }

    function getContribution(uint256 _campaignId, address _contributor) 
        external 
        view 
        returns (uint256) 
    {
        require(_campaignId < campaignCounter, "Invalid campaign ID");
        return campaigns[_campaignId].contributions[_contributor];
    }

    function _getETHPriceInUSD(uint256 _ethAmount) internal view returns (uint256) {
        PriceOracle memory oracle = oracles[address(0)];
        if (!oracle.active) return 0;

        (, int256 price, , uint256 updatedAt, ) = oracle.priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        require(updatedAt > 0, "Price data stale");

        return (_ethAmount * uint256(price) * PRICE_PRECISION) / (10 ** (oracle.decimals + 18));
    }

    function _getTokenPriceInUSD(address _token, uint256 _amount) internal view returns (uint256) {
        PriceOracle memory oracle = oracles[_token];
        if (!oracle.active) return 0;

        (, int256 price, , uint256 updatedAt, ) = oracle.priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        require(updatedAt > 0, "Price data stale");

        uint8 tokenDecimals = IERC20(_token).decimals();
        return (_amount * uint256(price) * PRICE_PRECISION) / (10 ** (oracle.decimals + tokenDecimals));
    }

    function _getUSDPriceInETH(uint256 _usdAmount) internal view returns (uint256) {
        PriceOracle memory oracle = oracles[address(0)];
        if (!oracle.active) return 0;

        (, int256 price, , uint256 updatedAt, ) = oracle.priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        require(updatedAt > 0, "Price data stale");

        return (_usdAmount * (10 ** (oracle.decimals + 18))) / (uint256(price) * PRICE_PRECISION);
    }
}