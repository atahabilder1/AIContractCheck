// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public totalRaised;
    bool public fundingSuccessful;
    bool public fundingClosed;

    mapping(address => uint) public contributions;

    event FundingReceived(address contributor, uint amount);
    event FundingSuccessful();
    event FundingClosed();

    constructor(uint _goal, uint _durationInDays) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier fundingOpen() {
        require(block.timestamp < deadline && !fundingClosed, "Funding is closed");
        _;
    }

    function contribute() external payable fundingOpen {
        require(msg.value > 0, "Contribution must be greater than 0");
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit FundingReceived(msg.sender, msg.value);

        checkFundingSuccess();
    }

    function checkFundingSuccess() internal {
        if (totalRaised >= goal) {
            fundingSuccessful = true;
            emit FundingSuccessful();
        }
    }

    function closeFunding() external onlyOwner {
        require(block.timestamp >= deadline || fundingSuccessful, "Funding cannot be closed yet");
        fundingClosed = true;
        emit FundingClosed();
        if (fundingSuccessful) {
            payable(owner).transfer(totalRaised);
        } else {
            for (address contributor : contributions.keys()) {
                payable(contributor).transfer(contributions[contributor]);
            }
        }
    }
}