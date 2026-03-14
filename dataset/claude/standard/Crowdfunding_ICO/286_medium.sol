// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CampaignToken is ERC20 {
    address public minter;

    constructor(string memory name, string memory symbol, address _minter) ERC20(name, symbol) {
        minter = _minter;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "Only minter");
        _mint(to, amount);
    }
}

contract CrowdfundingPlatform is Ownable, ReentrancyGuard {
    struct StretchGoal {
        uint256 threshold;
        string description;
        bool reached;
    }

    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 deadline;
        uint256 totalFunded;
        bool finalized;
        bool goalMet;
        address tokenAddress;
        uint256 tokensPerEth;
        uint256 stretchGoalCount;
        mapping(uint256 => StretchGoal) stretchGoals;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    uint256 public platformFeeBps = 250; // 2.5%

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goalAmount, uint256 deadline);
    event Funded(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event Refunded(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignFinalized(uint256 indexed campaignId, bool goalMet, uint256 totalFunded);
    event StretchGoalReached(uint256 indexed campaignId, uint256 goalIndex, uint256 threshold);
    event TokensDistributed(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function createCampaign(
        string calldata _title,
        string calldata _description,
        uint256 _goalAmount,
        uint256 _durationSeconds,
        string calldata _tokenName,
        string calldata _tokenSymbol,
        uint256 _tokensPerEth
    ) external returns (uint256 campaignId) {
        require(_goalAmount > 0, "Goal must be > 0");
        require(_durationSeconds > 0, "Duration must be > 0");
        require(_tokensPerEth > 0, "Tokens per ETH must be > 0");

        campaignId = campaignCount++;
        Campaign storage c = campaigns[campaignId];
        c.creator = msg.sender;
        c.title = _title;
        c.description = _description;
        c.goalAmount = _goalAmount;
        c.deadline = block.timestamp + _durationSeconds;
        c.tokensPerEth = _tokensPerEth;

        CampaignToken token = new CampaignToken(_tokenName, _tokenSymbol, address(this));
        c.tokenAddress = address(token);

        emit CampaignCreated(campaignId, msg.sender, _goalAmount, c.deadline);
    }

    function addStretchGoal(uint256 _campaignId, uint256 _threshold, string calldata _description) external {
        Campaign storage c = campaigns[_campaignId];
        require(msg.sender == c.creator, "Not creator");
        require(block.timestamp < c.deadline, "Campaign ended");
        require(!c.finalized, "Already finalized");
        require(_threshold > c.goalAmount, "Stretch goal must exceed base goal");

        if (c.stretchGoalCount > 0) {
            require(_threshold > c.stretchGoals[c.stretchGoalCount - 1].threshold, "Must exceed previous stretch goal");
        }

        uint256 idx = c.stretchGoalCount++;
        c.stretchGoals[idx] = StretchGoal({
            threshold: _threshold,
            description: _description,
            reached: false
        });
    }

    function fund(uint256 _campaignId) external payable nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(block.timestamp < c.deadline, "Campaign ended");
        require(!c.finalized, "Already finalized");
        require(msg.value > 0, "Must send ETH");

        if (c.contributions[msg.sender] == 0) {
            c.contributors.push(msg.sender);
        }
        c.contributions[msg.sender] += msg.value;
        c.totalFunded += msg.value;

        _checkStretchGoals(_campaignId);

        emit Funded(_campaignId, msg.sender, msg.value);
    }

    function _checkStretchGoals(uint256 _campaignId) internal {
        Campaign storage c = campaigns[_campaignId];
        for (uint256 i = 0; i < c.stretchGoalCount; i++) {
            if (!c.stretchGoals[i].reached && c.totalFunded >= c.stretchGoals[i].threshold) {
                c.stretchGoals[i].reached = true;
                emit StretchGoalReached(_campaignId, i, c.stretchGoals[i].threshold);
            }
        }
    }

    function finalize(uint256 _campaignId) external nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(block.timestamp >= c.deadline, "Campaign not ended");
        require(!c.finalized, "Already finalized");

        c.finalized = true;
        c.goalMet = c.totalFunded >= c.goalAmount;

        if (c.goalMet) {
            uint256 fee = (c.totalFunded * platformFeeBps) / 10000;
            uint256 creatorAmount = c.totalFunded - fee;

            (bool sentCreator,) = c.creator.call{value: creatorAmount}("");
            require(sentCreator, "Creator transfer failed");

            if (fee > 0) {
                (bool sentFee,) = owner().call{value: fee}("");
                require(sentFee, "Fee transfer failed");
            }

            _distributeTokens(_campaignId);
        }

        emit CampaignFinalized(_campaignId, c.goalMet, c.totalFunded);
    }

    function _distributeTokens(uint256 _campaignId) internal {
        Campaign storage c = campaigns[_campaignId];
        CampaignToken token = CampaignToken(c.tokenAddress);

        for (uint256 i = 0; i < c.contributors.length; i++) {
            address contributor = c.contributors[i];
            uint256 contribution = c.contributions[contributor];
            if (contribution > 0) {
                uint256 tokenAmount = (contribution * c.tokensPerEth) / 1 ether;
                if (tokenAmount > 0) {
                    token.mint(contributor, tokenAmount);
                    emit TokensDistributed(_campaignId, contributor, tokenAmount);
                }
            }
        }
    }

    function claimRefund(uint256 _campaignId) external nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(c.finalized, "Not finalized");
        require(!c.goalMet, "Goal was met");

        uint256 amount = c.contributions[msg.sender];
        require(amount > 0, "No contribution");

        c.contributions[msg.sender] = 0;

        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Refund failed");

        emit Refunded(_campaignId, msg.sender, amount);
    }

    function getContribution(uint256 _campaignId, address _contributor) external view returns (uint256) {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function getStretchGoal(uint256 _campaignId, uint256 _goalIndex) external view returns (uint256 threshold, string memory description, bool reached) {
        StretchGoal storage sg = campaigns[_campaignId].stretchGoals[_goalIndex];
        return (sg.threshold, sg.description, sg.reached);
    }

    function getContributors(uint256 _campaignId) external view returns (address[] memory) {
        return campaigns[_campaignId].contributors;
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Fee too high");
        platformFeeBps = _feeBps;
    }
}