// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleCrowdfunding {
    address payable public owner;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalContributed;
    bool public ownerWithdrawn;

    mapping(address => uint256) public contributions;

    constructor(uint256 goalWei, uint256 durationSeconds) {
        owner = payable(msg.sender);
        goal = goalWei;
        deadline = block.timestamp + durationSeconds;
    }

    receive() external payable {
        contribute();
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "Crowdfunding ended");
        require(msg.value > 0, "No ETH sent");
        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;
    }

    function withdrawOwner() external {
        require(msg.sender == owner, "Not owner");
        require(block.timestamp >= deadline, "Not ended");
        require(totalContributed >= goal, "Goal not met");
        require(!ownerWithdrawn, "Already withdrawn");
        ownerWithdrawn = true;
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "Transfer failed");
    }

    function refund() external {
        require(block.timestamp >= deadline, "Not ended");
        require(totalContributed < goal, "Goal met");
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "Nothing to refund");
        contributions[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Refund failed");
    }
}