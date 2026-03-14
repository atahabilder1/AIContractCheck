// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 amountRaised;
        bool claimed;
        mapping(address => uint256) contributions;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;

    event CampaignCreated(uint256 indexed id, address creator, uint256 goal, uint256 deadline);
    event Contributed(uint256 indexed id, address contributor, uint256 amount);
    event Claimed(uint256 indexed id, uint256 amount);
    event Refunded(uint256 indexed id, address contributor, uint256 amount);

    function createCampaign(
        string calldata _title,
        string calldata _description,
        uint256 _goal,
        uint256 _durationSeconds
    ) external returns (uint256) {
        uint256 id = campaignCount++;
        Campaign storage c = campaigns[id];
        c.creator = payable(msg.sender);
        c.title = _title;
        c.description = _description;
        c.goal = _goal;
        c.deadline = block.timestamp + _durationSeconds;

        emit CampaignCreated(id, msg.sender, _goal, c.deadline);
        return id;
    }

    function contribute(uint256 _id) external payable {
        Campaign storage c = campaigns[_id];
        require(block.timestamp < c.deadline, "Campaign ended");
        require(msg.value > 0, "Must send ETH");

        c.contributions[msg.sender] += msg.value;
        c.amountRaised += msg.value;

        emit Contributed(_id, msg.sender, msg.value);
    }

    function claim(uint256 _id) external {
        Campaign storage c = campaigns[_id];
        require(msg.sender == c.creator, "Not creator");
        require(block.timestamp >= c.deadline, "Campaign not ended");
        require(c.amountRaised >= c.goal, "Goal not reached");
        require(!c.claimed, "Already claimed");

        c.claimed = true;
        uint256 amount = c.amountRaised;
        c.creator.transfer(amount);

        emit Claimed(_id, amount);
    }

    function refund(uint256 _id) external {
        Campaign storage c = campaigns[_id];
        require(block.timestamp >= c.deadline, "Campaign not ended");
        require(c.amountRaised < c.goal, "Goal was reached");

        uint256 amount = c.contributions[msg.sender];
        require(amount > 0, "No contribution");

        c.contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit Refunded(_id, msg.sender, amount);
    }

    function getContribution(uint256 _id, address _contributor) external view returns (uint256) {
        return campaigns[_id].contributions[_contributor];
    }
}