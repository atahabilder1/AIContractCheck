// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Crowdfunding is Ownable {
    address public immutable stablecoinAddress;
    AggregatorV3Interface public immutable priceFeed;

    uint256 public immutable fundingGoal;
    uint256 public fundingDeadline;
    uint256 public amountRaised;
    bool public campaignEnded = false;

    struct Contributor {
        uint256 ethAmount;
        uint256 stablecoinAmount;
    }

    mapping(address => Contributor) public contributors;

    event Contribution(address indexed contributor, uint256 ethAmount, uint256 stablecoinAmount);
    event Withdrawal(address indexed recipient, uint256 amount);
    event Refund(address indexed contributor, uint256 amount);
    event CampaignFinished(bool success);

    modifier onlyBeforeDeadline() {
        require(block.timestamp < fundingDeadline, "Campaign has ended");
        _;
    }

    modifier onlyAfterDeadline() {
        require(block.timestamp >= fundingDeadline, "Campaign is still active");
        _;
    }

    modifier onlyCampaignNotEnded() {
        require(!campaignEnded, "Campaign has already ended");
        _;
    }

    constructor(
        address _stablecoinAddress,
        address _priceFeedAddress,
        uint256 _fundingGoal, // in USD
        uint256 _fundingDuration // in seconds
    ) Ownable(msg.sender) {
        stablecoinAddress = _stablecoinAddress;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        fundingGoal = _fundingGoal * 1e18; // Assume funding goal is in USD, convert to base units for calculations
        fundingDeadline = block.timestamp + _fundingDuration;
    }

    function contribute() external payable onlyBeforeDeadline onlyCampaignNotEnded {
        uint256 ethAmount = msg.value;
        uint256 stablecoinAmount = 0;

        if (ethAmount > 0) {
            (int256 price, , , , ) = priceFeed.latestRoundData();
            uint256 ethPriceInUSD = uint256(price); // Price is in USD/ETH, scaled by 1e8

            // Calculate equivalent stablecoin amount for the ETH contributed
            // ethAmount is in wei (1e18), ethPriceInUSD is scaled by 1e8
            // stablecoinAmount = (ethAmount * ethPriceInUSD) / 1e18 / 1e8
            stablecoinAmount = (ethAmount * ethPriceInUSD) / 1e26; // Combined scaling factor

            contributors[msg.sender].ethAmount += ethAmount;
            contributors[msg.sender].stablecoinAmount += stablecoinAmount;
            amountRaised += stablecoinAmount;
        }

        emit Contribution(msg.sender, ethAmount, stablecoinAmount);
    }

    function contributeWithStablecoin(uint256 _amount) external onlyBeforeDeadline onlyCampaignNotEnded {
        require(_amount > 0, "Amount must be greater than zero");

        IERC20 stablecoin = IERC20(stablecoinAddress);
        require(stablecoin.transferFrom(msg.sender, address(this), _amount), "Stablecoin transfer failed");

        contributors[msg.sender].stablecoinAmount += _amount;
        amountRaised += _amount;

        emit Contribution(msg.sender, 0, _amount);
    }

    function endCampaign() public onlyAfterDeadline {
        require(!campaignEnded, "Campaign already ended");
        campaignEnded = true;

        if (amountRaised >= fundingGoal) {
            emit CampaignFinished(true);
        } else {
            emit CampaignFinished(false);
            // If not successful, contributors can refund
        }
    }

    function withdrawFunds() public onlyOwner onlyAfterDeadline {
        require(campaignEnded, "Campaign must be ended");
        require(amountRaised >= fundingGoal, "Funding goal not met");
        require(address(this).balance > 0, "No ETH balance to withdraw");

        uint256 amount = address(this).balance;
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "ETH withdrawal failed");

        emit Withdrawal(owner(), amount);
    }

    function withdrawStablecoins() public onlyOwner onlyAfterDeadline {
        require(campaignEnded, "Campaign must be ended");
        require(amountRaised >= fundingGoal, "Funding goal not met");

        uint256 amount = IERC20(stablecoinAddress).balanceOf(address(this));
        require(amount > 0, "No stablecoin balance to withdraw");

        require(IERC20(stablecoinAddress).transfer(owner(), amount), "Stablecoin withdrawal failed");

        emit Withdrawal(owner(), amount);
    }

    function refund() public onlyAfterDeadline {
        require(campaignEnded, "Campaign must be ended");
        require(amountRaised < fundingGoal, "Funding goal was met, no refunds");

        Contributor storage contributor = contributors[msg.sender];
        uint256 totalRefundAmount = contributor.ethAmount + contributor.stablecoinAmount; // Assuming stablecoin is pegged 1:1 to USD

        require(totalRefundAmount > 0, "No contributions to refund");

        // Refund ETH
        if (contributor.ethAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: contributor.ethAmount}("");
            require(success, "ETH refund failed");
            emit Refund(msg.sender, contributor.ethAmount);
        }

        // Refund Stablecoin
        if (contributor.stablecoinAmount > 0) {
            require(IERC20(stablecoinAddress).transfer(msg.sender, contributor.stablecoinAmount), "Stablecoin refund failed");
            emit Refund(msg.sender, contributor.stablecoinAmount);
        }

        // Reset contributor's amounts
        contributor.ethAmount = 0;
        contributor.stablecoinAmount = 0;
    }

    // Fallback function to receive ETH directly if needed, though `contribute` is preferred
    receive() external payable {
        contribute();
    }

    // Function to get current ETH price in USD
    function getEthPrice() public view returns (uint256) {
        (int256 price, , , , ) = priceFeed.latestRoundData();
        return uint256(price); // Scaled by 1e8
    }

    // Function to get total amount raised in USD (approximate, based on current price for ETH contributions)
    function getTotalRaisedUSD() public view returns (uint256) {
        uint256 ethRaisedInUSD = 0;
        if (amountRaised > 0) {
            // This calculation is an approximation as it uses the current price.
            // A more accurate tracking would store the USD value of ETH contributions at the time of contribution.
            // For simplicity in this example, we'll consider the total amount raised as the sum of stablecoins and the USD value of ETH contributions.
            // The `amountRaised` variable already stores the stablecoin equivalent value of contributions.
            // To get a more precise USD total, we'd need to re-evaluate ETH contributions based on their original USD value at the time of contribution.
            // For this example, we'll assume `amountRaised` is the primary metric and reflects the USD value.
            // If you contributed ETH, its USD value at the time of contribution was converted and added to `amountRaised`.
        }
        return amountRaised;
    }

    // Function to get remaining time
    function getRemainingTime() public view returns (uint256) {
        if (block.timestamp >= fundingDeadline) {
            return 0;
        }
        return fundingDeadline - block.timestamp;
    }
}