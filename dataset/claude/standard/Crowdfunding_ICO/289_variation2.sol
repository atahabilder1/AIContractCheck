// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

contract CrowdfundingMultiAsset is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Campaign {
        address creator;
        uint256 goalUsd;
        uint256 raisedUsd;
        uint256 deadline;
        bool claimed;
        bool cancelled;
    }

    struct StablecoinConfig {
        bool accepted;
        AggregatorV3Interface priceFeed;
        uint8 tokenDecimals;
    }

    AggregatorV3Interface public immutable ethUsdPriceFeed;
    uint256 public campaignCount;

    mapping(uint256 => Campaign) public campaigns;
    mapping(address => StablecoinConfig) public stablecoins;
    mapping(uint256 => mapping(address => uint256)) public ethContributions;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public tokenContributions;

    address public owner;
    uint256 public constant STALENESS_THRESHOLD = 3600;
    uint256 public constant USD_DECIMALS = 8;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goalUsd, uint256 deadline);
    event ContributedETH(uint256 indexed campaignId, address indexed contributor, uint256 ethAmount, uint256 usdValue);
    event ContributedToken(uint256 indexed campaignId, address indexed contributor, address token, uint256 amount, uint256 usdValue);
    event FundsClaimed(uint256 indexed campaignId, address indexed creator);
    event RefundClaimed(uint256 indexed campaignId, address indexed contributor);
    event CampaignCancelled(uint256 indexed campaignId);
    event StablecoinUpdated(address indexed token, bool accepted, address priceFeed, uint8 tokenDecimals);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _ethUsdPriceFeed) {
        require(_ethUsdPriceFeed != address(0), "Invalid price feed");
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        owner = msg.sender;
    }

    function setStablecoin(address _token, bool _accepted, address _priceFeed, uint8 _tokenDecimals) external onlyOwner {
        require(_token != address(0), "Invalid token");
        if (_accepted) {
            require(_priceFeed != address(0), "Invalid price feed");
        }
        stablecoins[_token] = StablecoinConfig({
            accepted: _accepted,
            priceFeed: AggregatorV3Interface(_priceFeed),
            tokenDecimals: _tokenDecimals
        });
        emit StablecoinUpdated(_token, _accepted, _priceFeed, _tokenDecimals);
    }

    function createCampaign(uint256 _goalUsd, uint256 _durationSeconds) external returns (uint256) {
        require(_goalUsd > 0, "Goal must be > 0");
        require(_durationSeconds > 0, "Duration must be > 0");

        uint256 campaignId = campaignCount++;
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            goalUsd: _goalUsd,
            raisedUsd: 0,
            deadline: block.timestamp + _durationSeconds,
            claimed: false,
            cancelled: false
        });

        emit CampaignCreated(campaignId, msg.sender, _goalUsd, block.timestamp + _durationSeconds);
        return campaignId;
    }

    function contributeETH(uint256 _campaignId) external payable nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(c.creator != address(0), "Campaign does not exist");
        require(block.timestamp < c.deadline, "Campaign ended");
        require(!c.cancelled, "Campaign cancelled");
        require(msg.value > 0, "Must send ETH");

        uint256 usdValue = getEthUsdValue(msg.value);
        c.raisedUsd += usdValue;
        ethContributions[_campaignId][msg.sender] += msg.value;

        emit ContributedETH(_campaignId, msg.sender, msg.value, usdValue);
    }

    function contributeToken(uint256 _campaignId, address _token, uint256 _amount) external nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(c.creator != address(0), "Campaign does not exist");
        require(block.timestamp < c.deadline, "Campaign ended");
        require(!c.cancelled, "Campaign cancelled");
        require(_amount > 0, "Amount must be > 0");

        StablecoinConfig memory config = stablecoins[_token];
        require(config.accepted, "Token not accepted");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 usdValue = getTokenUsdValue(_token, _amount);
        c.raisedUsd += usdValue;
        tokenContributions[_campaignId][msg.sender][_token] += _amount;

        emit ContributedToken(_campaignId, msg.sender, _token, _amount, usdValue);
    }

    function claimFunds(uint256 _campaignId, address[] calldata _tokens) external nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(msg.sender == c.creator, "Not creator");
        require(block.timestamp >= c.deadline, "Campaign not ended");
        require(!c.claimed, "Already claimed");
        require(!c.cancelled, "Campaign cancelled");
        require(c.raisedUsd >= c.goalUsd, "Goal not reached");

        c.claimed = true;

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success,) = payable(c.creator).call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 balance = IERC20(_tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                IERC20(_tokens[i]).safeTransfer(c.creator, balance);
            }
        }

        emit FundsClaimed(_campaignId, c.creator);
    }

    function refund(uint256 _campaignId, address[] calldata _tokens) external nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(
            c.cancelled || (block.timestamp >= c.deadline && c.raisedUsd < c.goalUsd),
            "Refund not available"
        );

        uint256 ethAmount = ethContributions[_campaignId][msg.sender];
        if (ethAmount > 0) {
            ethContributions[_campaignId][msg.sender] = 0;
            (bool success,) = payable(msg.sender).call{value: ethAmount}("");
            require(success, "ETH refund failed");
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 tokenAmount = tokenContributions[_campaignId][msg.sender][_tokens[i]];
            if (tokenAmount > 0) {
                tokenContributions[_campaignId][msg.sender][_tokens[i]] = 0;
                IERC20(_tokens[i]).safeTransfer(msg.sender, tokenAmount);
            }
        }

        emit RefundClaimed(_campaignId, msg.sender);
    }

    function cancelCampaign(uint256 _campaignId) external {
        Campaign storage c = campaigns[_campaignId];
        require(msg.sender == c.creator, "Not creator");
        require(!c.claimed, "Already claimed");
        require(!c.cancelled, "Already cancelled");

        c.cancelled = true;
        emit CampaignCancelled(_campaignId);
    }

    function getEthUsdValue(uint256 _ethAmount) public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH price");
        require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "Stale ETH price");

        uint8 feedDecimals = ethUsdPriceFeed.decimals();
        return (_ethAmount * uint256(price)) / (10 ** (18 + feedDecimals - USD_DECIMALS));
    }

    function getTokenUsdValue(address _token, uint256 _amount) public view returns (uint256) {
        StablecoinConfig memory config = stablecoins[_token];
        require(config.accepted, "Token not accepted");

        (, int256 price,, uint256 updatedAt,) = config.priceFeed.latestRoundData();
        require(price > 0, "Invalid token price");
        require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "Stale token price");

        uint8 feedDecimals = config.priceFeed.decimals();
        return (_amount * uint256(price)) / (10 ** (uint256(config.tokenDecimals) + feedDecimals - USD_DECIMALS));
    }
}