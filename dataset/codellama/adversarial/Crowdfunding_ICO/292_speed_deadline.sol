// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    // Campaign owner
    address public owner;

    // Campaign deadline
    uint public deadline;

    // Campaign goal
    uint public goal;

    // Total amount raised
    uint public amountRaised;

    // Amount of funds contributed by each backer
    mapping(address => uint) public contributions;

    // Whether the campaign has been successful
    bool public successful;

    // Event to trigger when funds are contributed
    event FundsContributed(address contributor, uint amount);

    // Event to trigger when the campaign is successful
    event CampaignSuccessful();

    // Constructor to initialize the campaign
    constructor(uint _goal, uint _deadline) public {
        owner = msg.sender;
        goal = _goal;
        deadline = _deadline;
    }

    // Function to contribute to the campaign
    function contribute() public payable {
        require(msg.value > 0, "Invalid contribution amount");
        require(contributions[msg.sender] + msg.value <= goal, "Contribution exceeds goal");

        contributions[msg.sender] += msg.value;
        amountRaised += msg.value;

        emit FundsContributed(msg.sender, msg.value);

        if (amountRaised >= goal) {
            successful = true;
            emit CampaignSuccessful();
        }
    }

    // Function to retrieve the campaign's information
    function getCampaignInfo() public view returns (uint, uint, uint, bool) {
        return (goal, deadline, amountRaised, successful);
    }

    // Function to retrieve the campaign's backers
    function getBackers() public view returns (address[]) {
        address[] memory backers = new address[](contributions.length);
        uint i = 0;
        for (address contributor : contributions.keys()) {
            backers[i++] = contributor;
        }
        return backers;
    }
}