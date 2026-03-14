// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingICO {
    address public owner;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalRaised;
    uint256 public tokenPrice;
    bool public isGoalReached;
    bool public isICOEnded;

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokenBalance;

    event ContributionReceived(address contributor, uint256 amount);
    event TokensPurchased(address buyer, uint256 amount);
    event GoalReached(uint256 totalAmountRaised);
    event ICOEnded();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this");
        _;
    }

    modifier icoActive() {
        require(block.timestamp < deadline && !isICOEnded, "ICO is not active");
        _;
    }

    constructor(uint256 _goal, uint256 _duration, uint256 _tokenPrice) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _duration;
        tokenPrice = _tokenPrice;
    }

    function contribute() external payable icoActive {
        require(msg.value > 0, "Contribution must be greater than 0");
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit ContributionReceived(msg.sender, msg.value);

        if (totalRaised >= goal && !isGoalReached) {
            isGoalReached = true;
            emit GoalReached(totalRaised);
        }
    }

    function purchaseTokens() external payable icoActive {
        require(msg.value > 0, "Ether sent must be greater than 0");
        uint256 tokensToBuy = msg.value / tokenPrice;
        require(tokensToBuy > 0, "Not enough Ether to buy tokens");

        contributions[msg.sender] += msg.value;
        tokenBalance[msg.sender] += tokensToBuy;
        totalRaised += msg.value;

        emit TokensPurchased(msg.sender, tokensToBuy);

        if (totalRaised >= goal && !isGoalReached) {
            isGoalReached = true;
            emit GoalReached(totalRaised);
        }
    }

    function endICO() external onlyOwner {
        require(block.timestamp >= deadline || isGoalReached, "ICO cannot be ended yet");
        require(!isICOEnded, "ICO has already ended");

        isICOEnded = true;

        if (totalRaised >= goal) {
            payable(owner).transfer(totalRaised);
        } else {
            refundAll();
        }

        emit ICOEnded();
    }

    function refundAll() internal {
        for (address contributor = address(0); contributor <= address(type(uint160).max); contributor++) {
            uint256 amount = contributions[contributor];
            if (amount > 0) {
                contributions[contributor] = 0;
                payable(contributor).transfer(amount);
            }
        }
    }

    function withdrawTokens() external {
        require(isICOEnded, "ICO must be ended to withdraw tokens");
        uint256 amount = tokenBalance[msg.sender];
        require(amount > 0, "No tokens to withdraw");

        tokenBalance[msg.sender] = 0;
        // Logic to transfer tokens to msg.sender should be implemented here
    }
}