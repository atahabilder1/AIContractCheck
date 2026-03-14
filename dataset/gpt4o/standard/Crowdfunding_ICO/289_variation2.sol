// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Crowdfunding {
    address public owner;
    address public stablecoin;
    IPriceFeed public ethUsdPriceFeed;
    IPriceFeed public stablecoinUsdPriceFeed;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalFundingUsd;

    mapping(address => uint256) public contributions;

    event ContributionReceived(address contributor, uint256 amountUsd);
    event Withdrawn(address recipient, uint256 amountUsd);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier activeCampaign() {
        require(block.timestamp <= deadline, "Campaign is over");
        _;
    }

    constructor(
        address _stablecoin,
        address _ethUsdPriceFeed,
        address _stablecoinUsdPriceFeed,
        uint256 _goalUsd,
        uint256 _duration
    ) {
        owner = msg.sender;
        stablecoin = _stablecoin;
        ethUsdPriceFeed = IPriceFeed(_ethUsdPriceFeed);
        stablecoinUsdPriceFeed = IPriceFeed(_stablecoinUsdPriceFeed);
        goal = _goalUsd;
        deadline = block.timestamp + _duration;
    }

    function contributeEth() external payable activeCampaign {
        require(msg.value > 0, "No ETH sent");
        uint256 ethUsdPrice = uint256(ethUsdPriceFeed.latestAnswer());
        uint256 contributionUsd = (msg.value * ethUsdPrice) / 1e18;
        contributions[msg.sender] += contributionUsd;
        totalFundingUsd += contributionUsd;
        emit ContributionReceived(msg.sender, contributionUsd);
    }

    function contributeStablecoin(uint256 amount) external activeCampaign {
        require(amount > 0, "No stablecoin sent");
        uint256 stablecoinUsdPrice = uint256(stablecoinUsdPriceFeed.latestAnswer());
        require(stablecoinUsdPrice > 0, "Invalid stablecoin price");
        uint256 contributionUsd = (amount * stablecoinUsdPrice) / 1e18;
        IERC20(stablecoin).transferFrom(msg.sender, address(this), amount);
        contributions[msg.sender] += contributionUsd;
        totalFundingUsd += contributionUsd;
        emit ContributionReceived(msg.sender, contributionUsd);
    }

    function withdraw() external onlyOwner {
        require(block.timestamp > deadline, "Campaign is still active");
        require(totalFundingUsd >= goal, "Funding goal not reached");

        uint256 stablecoinBalance = IERC20(stablecoin).balanceOf(address(this));
        if (stablecoinBalance > 0) {
            IERC20(stablecoin).transfer(owner, stablecoinBalance);
        }

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner).transfer(ethBalance);
        }

        emit Withdrawn(owner, totalFundingUsd);
    }

    function refund() external {
        require(block.timestamp > deadline, "Campaign is still active");
        require(totalFundingUsd < goal, "Funding goal was reached");
        uint256 contributionUsd = contributions[msg.sender];
        require(contributionUsd > 0, "No contributions found");

        contributions[msg.sender] = 0;

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            uint256 ethUsdPrice = uint256(ethUsdPriceFeed.latestAnswer());
            uint256 refundEth = (contributionUsd * 1e18) / ethUsdPrice;
            payable(msg.sender).transfer(refundEth);
        }

        uint256 stablecoinBalance = IERC20(stablecoin).balanceOf(address(this));
        if (stablecoinBalance > 0) {
            uint256 stablecoinUsdPrice = uint256(stablecoinUsdPriceFeed.latestAnswer());
            uint256 refundStablecoin = (contributionUsd * 1e18) / stablecoinUsdPrice;
            IERC20(stablecoin).transfer(msg.sender, refundStablecoin);
        }
    }
}